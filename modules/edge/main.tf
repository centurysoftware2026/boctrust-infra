data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

locals {
  default_origin = var.admin_site == null ? "none" : "admin-site"
}

# All three APIs share the /api/v1 prefix, so each gets its own path here and the prefix is stripped before the ALB.
# The dashboard owns the rest of the URL space, hence the /api/ namespace.
resource "aws_cloudfront_function" "strip_prefix" {
  for_each = var.services

  name    = "${var.name}-strip-${each.key}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      request.uri = request.uri.replace(/^\/api\/${each.key}(\/|$)/, '/');
      return request;
    }
  JS
}

# Single page app: any path without a file extension serves index.html.
resource "aws_cloudfront_function" "spa" {
  name    = "${var.name}-spa"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      if (!/\.[A-Za-z0-9]+$/.test(request.uri)) {
        request.uri = '/index.html';
      }
      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  comment         = var.name
  is_ipv6_enabled = true
  http_version    = "http2and3"

  # Cheapest edge set (North America and Europe). Widen if users are mostly elsewhere.
  price_class = "PriceClass_100"

  dynamic "origin" {
    for_each = var.services

    content {
      origin_id   = origin.key
      domain_name = var.alb_dns_name

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      custom_header {
        name  = "x-origin-verify"
        value = var.origin_verify_secret
      }

      custom_header {
        name  = "x-target-service"
        value = origin.key
      }
    }
  }

  # Used by the default behaviour when there is no dashboard. No ALB rule matches "none", so the ALB answers 403.
  origin {
    origin_id   = "none"
    domain_name = var.alb_dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "x-target-service"
      value = "none"
    }
  }

  dynamic "origin" {
    for_each = var.admin_site == null ? [] : [var.admin_site]

    content {
      origin_id                = "admin-site"
      domain_name              = origin.value.bucket_regional_domain_name
      origin_access_control_id = origin.value.origin_access_control_id
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.services

    content {
      path_pattern             = "/api/${ordered_cache_behavior.key}/*"
      target_origin_id         = ordered_cache_behavior.key
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
      compress                 = true

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.strip_prefix[ordered_cache_behavior.key].arn
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = local.default_origin
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = var.admin_site == null ? data.aws_cloudfront_cache_policy.disabled.id : data.aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id = var.admin_site == null ? data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id : null

    dynamic "function_association" {
      for_each = var.admin_site == null ? [] : [1]

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.spa.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Switch to an ACM certificate and alias names when the domain exists.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
