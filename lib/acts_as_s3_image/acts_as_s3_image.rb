module AUPEO
  module Acts
    module S3Image
      
      class NoSizesHash < Exception;end
      class NoExtensionColumn < Exception;end
      
      def self.included(base)
        base.extend ActMacro
      end
      
      module ActMacro
        # Configuration options are
        # * +extension_column - which column to lookup for image extension (jpg, gif) in the original table
        # * +sizes+ - hash with all possible labels and their dimensions, as in {"thumb"=>[50,50]} 
        # You can also especify if the dimension should be of that fixed size (it will be cropped to be perfectly 50x50 in {"thumb"=>[50,50,"fixed"]})
        # The default is to limit the image, say by 50x50, but keep the aspect within those boundaries, so it can be 40x50 but never 55x50.
        # * +use_backgroundrb - optional param, set it to true to use the backgroundrb s3_image_worker, it will pass on the original image on creation so
        # the worker creates all the other sizes from it in the background (needs backgroundrb, of course)
        def acts_as_s3_image(options = {})
          class_eval do
            has_many :image_versions, :as => :imageversionable, :dependent => :destroy, :order => 'created_at DESC'
            validates_format_of :content_type, :with => /^image/, 
                                :message => "only image files are allowed!", 
                                :allow_nil => true,
                                :if => :has_picture?
            
            extend ClassMethods
            include InstanceMethods
          
            raise NoSizesHash unless options[:sizes]
            raise NoExtensionColumn unless options[:extension_column]
            
            after_create :save_orig, :create_version
            after_update :save_orig, :update_version
          
            self.config = CONFIG
            self.extension = options[:extension_column].to_s
            self.sizes = options[:sizes]
            self.backgroundrb = options[:use_backgroundrb]
          end
             
        end
      end
      
      module InstanceMethods
        
        def path
          ["#{RAILS_ROOT}/tmp/#{self.class.to_s.underscore.pluralize.downcase}", "#{self.send(:id)}.#{self.send(self.class.extension.to_sym)}"] 
        end
        
        def picture=(picture)
         @picture = picture
         write_attribute :content_type, picture.content_type.chomp
         write_attribute :extension,
            picture.original_filename.split('.').last.downcase
        end
                
        private

        def has_picture?
          not @picture.nil?
        end

        def create_dir(dir)
          FileUtils.mkdir_p dir
        end
                
        def save_orig
          if @picture
            create_dir(self.path[0])
            File.open(self.path.join('/'), "wb") {|f| f << open(@picture).read }
          end
        end
        
        def create_version
          self.image_versions << ImageVersion.new(:state=>"unprocessed", :priority=>5)
        end
        
        def update_version
          if @picture
            version = self.image_versions.find(:first, :conditions=>"label is null")
            version.update_attributes(:state=>"unprocessed", :priority=>5)
          end
        end
              
      end
      
      module ClassMethods
        attr_accessor :extension, :config, :sizes, :backgroundrb
      end
      
    end
  end
end

