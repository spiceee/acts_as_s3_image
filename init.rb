require 'acts_as_s3_image'
ActiveRecord::Base.send(:include, AUPEO::Acts::S3Image)
ActionView::Base.send(:include, AUPEO::Acts::S3Image::ViewHelpers)
