module AUPEO
  module Acts
    module S3Image
      module SupportingClasses

        class S3ConfigFileNotFoundException < StandardError;end
        class S3ConfigErrorException < StandardError;end

        class Config

          attr_reader :docs

          def initialize
            unless File.exist?(RAILS_ROOT + '/config/s3_image.yml')
              raise S3ConfigFileNotFoundException.new("File #{RAILS_ROOT}/config/s3_image.yml not found")
            else
              @docs = []
              File.open(RAILS_ROOT + '/config/s3_image.yml') { |fh| YAML.each_document(fh) { |doc| @docs.push(doc) }}
            end
          end

          def s3
            doc = self.docs.first
            raise S3ConfigErrorException.new("There's no access_key_id in the config file") unless doc['s3']['access_key_id']
            raise S3ConfigErrorException.new("There's no secret_access_key in the config file") unless doc['s3']['secret_access_key']
            doc['s3']
          end

          def app
            doc = self.docs.first
            raise S3ConfigErrorException.new("There's no state_model in the config file") unless doc['app']['state_model']
            doc['app']
          end

          def env
            doc = self.docs[1]
            env = ENV['RAILS_ENV'] || RAILS_ENV
            raise S3ConfigErrorException.new("There's no #{RAILS_ENV} config in the config file") unless doc[env]
            doc[env]
          end

        end
      end
    end
  end
end
