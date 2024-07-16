# --cloud-front/main.tf -- # 
data "aws_s3_bucket" "selectedPrimary" {
  bucket = var.s3_primary
}

locals {
  s3_origin_id = "Web-S3Origin"
  nlb_origin_id = "Web-NetworkLoadBalancer"
}

resource "aws_cloudfront_origin_access_control" "cloudfront_s3_oac" {
  name                              = "CloudFront S3 OAC"
  description                       = "Cloud Front S3 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "my_distrib" {

  origin {
    domain_name = data.aws_s3_bucket.selectedPrimary.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    #origin_id   = "${data.aws_s3_bucket.selectedPrimary.id}.s3.${var.region}.amazonaws.com"
    #origin_path = "/index.html"
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_s3_oac.id
    
  }

  origin {
    domain_name = var.nlb_dns_name
    origin_id   = local.nlb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }  
  
  enabled = true
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id
    
    forwarded_values {
      headers = []
      query_string = true

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

}

/*
resource "aws_cloudfront_distribution" "my_distrib" {

  origin_group {
    origin_id = "distribution"
    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }
    member {
      origin_id = "s3"
    }
    member {
      origin_id = "ec2"
    }
  }
  

  origin {
    domain_name = data.aws_s3_bucket.selected.bucket_regional_domain_name
    origin_id   = "s3"
    origin_path = "/index.html"
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_s3_oac.id
    
  }
  origin {
    origin_id = "ec2"
    domain_name = var.ec2_domain_name
    origin_path = "/index.html"
    custom_origin_config {
      http_port = 80
      https_port = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]

    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "distribution"
    

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

}*/

/*
resource "aws_cloudfront_distribution" "my_distrib" {
  origin {
    domain_name = var.s3_domain_name
    origin_id   = "s3"
    
  }
  
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

}
*/