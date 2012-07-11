module AUPEO
  module Acts
    module S3Image
      module ViewHelpers

        def s3_image_tag(obj, options={})
          return "" if options[:label].nil?

          if obj.nil? || (not ImageVersion.has_versions?(obj))
            options[:src] = "/images/no_image_" + options[:label] + ".jpg"
            options[:alt] = "no image"
            options.delete(:label)
            return tag(:img, options)
          end

          options.symbolize_keys!
          version = obj.image_versions.first.version_by_label(options[:label])
          sizes = obj.class.sizes

          if version.nil?
            # get original if version doesn't exist/ is missing
            version = obj.image_versions.first.original
            # force size wanted - this will produce an img tag with width and height to equal :label
            options[:width], options[:height] = (sizes[options[:label]])[(0..1)]
          end

          options[:src] = version.s3_url
          options[:alt] ||= File.basename(options[:src], '.*').split('.').first.capitalize
          options.delete(:label)
          tag(:img, options)
        end

        def s3_url_for_label(obj, label)
          return "" if obj.nil? || (not ImageVersion.has_versions?(obj))
          obj.image_versions.first.version_by_label(label).s3_url
        end

      end
    end
  end
end