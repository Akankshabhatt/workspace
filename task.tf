provider "aws" {
  region   = "ap-south-1"
  profile  = "akansha"
}

resource "aws_security_group" "allow_http" {
 name = "allow_httpd"
 description = "Allow port 80"
 vpc_id = "vpc-26839e4e"

 ingress {
  description = "HTTP"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }

 ingress {
  description = "SSH"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
  
 egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }
 
 tags = {
  Name = "allow_http"
 }
}


variable "enter_ur_key_name" {
 type = string
 default = "key11"
}

resource "aws_instance" "os" {
 ami = "ami-0447a12f28fddb066"
 instance_type = "t2.micro"
 key_name = var.enter_ur_key_name
 security_groups = ["${aws_security_group.allow_http.name}"]

 connection {
  type = "ssh"
  user = "ec2-user"
  private_key = file("C:/Users/HARSH/Downloads/key11.pem")
  host = aws_instance.os.public_ip
 }

 provisioner "remote-exec" {
  inline = [
   "sudo yum install httpd php git -y",
   "sudo systemctl restart httpd",
   "sudo systemctl enable httpd",
  ] 
 }
 tags = {
  Name = "Path"
 }
}

resource "aws_ebs_volume" "ebs1" {
 depends_on = [
  aws_instance.os,
 ]
 
 availability_zone = aws_instance.os.availability_zone
 size = 1
 tags = {
  Name = "myebs"
 }
}

resource "aws_volume_attachment" "ebs_att" {
 depends_on = [
  aws_ebs_volume.ebs1,
 ]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.os.id
  force_detach = true
}

resource "null_resource" "nullremote" {
 depends_on = [
  aws_volume_attachment.ebs_att,
 ]
 
 connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = file("C:/Users/HARSH/Downloads/key11.pem")
  host     = aws_instance.os.public_ip
 }

 provisioner "remote-exec" {
  inline = [
   "sudo mkfs.ext4  /dev/xvdh",
   "sudo mount  /dev/xvdh  /var/www/html",
   "sudo rm -rf /var/www/html/*",
   "sudo git clone https://github.com/Akankshabhatt/workspace.git /var/www/html/"
  ]
 }
}

resource "aws_s3_bucket" "mybucket" {
 bucket = "akanshabkt"
 acl = "public-read"
 force_destroy = true

 provisioner "local-exec" {
  command = "git clone https://github.com/Akankshabhatt/workspace.git terra-image" 
 }

 provisioner "local-exec" {
  when = destroy
  command = "echo Y | rmdir /s terra-image"
 }
}

resource "aws_s3_bucket_object" "image-upload" {
 bucket  = aws_s3_bucket.mybucket.bucket
 key     = "Path.jpg"
 source  = "terra-image/Path.jpg"
 acl = "public-read"
 content_type = "images/jpg"
 depends_on = [
  aws_s3_bucket.mybucket,
 ]
}
output "my_bucket_id"{
 value = aws_s3_bucket.mybucket.bucket
}

variable "my_id" {
 type = string
 default = "S3-"
}

locals {
 s3_origin_id = "${var.my_id}${aws_s3_bucket.mybucket.id}"
}

resource "aws_cloudfront_distribution" "distribution" {
	depends_on = [
  		aws_s3_bucket_object.image-upload,
 	]
 
 	origin {
  		domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
  		origin_id = "${local.s3_origin_id}"
 	} 
 
 	enabled = true
 
 	default_cache_behavior {
	 	allowed_methods = [ "GET", "HEAD", "OPTIONS"]
 		cached_methods = ["GET", "HEAD"]
 		target_origin_id = "${local.s3_origin_id}"

		forwarded_values {
  		query_string = false
  
  			cookies {
   			forward = "none"
  			}
 		}
 		viewer_protocol_policy = "allow-all"
 		min_ttl = 0
		default_ttl = 3600
 		max_ttl = 86400
	}

	restrictions {
 		geo_restriction {
  			restriction_type = "none"
 			}
	}

	viewer_certificate {
	cloudfront_default_certificate = true
	}
	connection {
	type = "ssh"
	user = "ec2-user"
	private_key = file("C:/Users/HARSH/Downloads/key11.pem")
	host = aws_instance.os.public_ip
	}
 
	provisioner "remote-exec"{
 	inline = [
	  	"sudo su <<END",
  	  	"echo \"<img src='http://${aws_cloudfront_distribution.distribution.domain_name}/${aws_s3_bucket_object.image-upload.key}' height='400' width='450'>\" >> /var/www/html/index.html",
  		"END",
 		]
	}
}
output "my_ip"{
 value = aws_instance.os.public_ip
}