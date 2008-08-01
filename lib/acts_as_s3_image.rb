require 'RMagick'
require 'aws/s3'
require 'acts_as_s3_image/config'
require 'acts_as_s3_image/acts_as_s3_image'
require 'acts_as_s3_image/image_version'
require 'acts_as_s3_image/view_helpers'

include AUPEO::Acts::S3Image::SupportingClasses
AUPEO::Acts::S3Image::CONFIG = AUPEO::Acts::S3Image::SupportingClasses::Config.new
