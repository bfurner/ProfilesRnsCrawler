variable "bucket_name" { 
  description = "The name of the S3 bucket"
  type        = string
}

variable "force_delete" { 
  description = "force deleting the bucket"
  type        = bool
}

variable "versioning" {
  description = "'Enabled' if the file with the same key on this bucket are versioned"
  type        = string
}

variable "encryption" { 
  description = "force deleting the bucket"
  type        = bool
  default     = false
}

variable "enable_lifecycle" { 
  description = "enable remove old files in S3"
  type        = bool
  default     = false
}

variable "days_to_expiration" {
  type        = number
  default     = 365
  description = "The amount of days after which a file is removed from the S3 bucket"
}

variable "enable_website_hosting" {
  description = "Whether to enable S3 static website hosting."
  type        = bool
  default     = false
}

variable "enable_eventbridge_notifications" {
  description = "Enable S3 EventBridge notifications for this bucket"
  type        = bool
  default     = false
}