module AUPEO
  module Acts
    module S3Image
      
      class NoSizesHash < Exception;end
      
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
                                :if => :uploaded?
            
            extend ClassMethods
            include InstanceMethods
          
            raise NoSizesHash unless options[:sizes]
            
            after_create :save_orig, :create_version
            after_update :save_orig, :update_version
          
            self.config = CONFIG
            self.sizes = options[:sizes]
            self.backgroundrb = options[:use_backgroundrb]
            self.convert_to = options[:convert_to].to_s
          end
             
        end
      end
      
      module InstanceMethods
        
        def path
          ["#{RAILS_ROOT}/tmp/s3_image/#{self.class.to_s.underscore.pluralize.downcase}", "#{self.send(:id)}.#{self.extension}"] 
        end
        
        def picture=(picture)
          @picture = picture
          write_attribute :content_type, picture.content_type.chomp if uploaded?
          if uploaded?
            write_attribute :extension, picture.original_filename.split('.').last.downcase
          else
            write_attribute :extension, picture.split('.').last.downcase
          end
        end
                
        private

        def uploaded?
          (not @picture.nil?) && (@picture.methods.include? 'content_type')
        end

        def create_dir(dir)
          FileUtils.mkdir_p dir
        end
                
        def save_orig
          if @picture
            create_dir(self.path[0])
            @picture.rewind if @picture.is_a? StringIO
            File.open(self.path.join('/'),'wb') do |f|
              f.puts @picture.read
            end
          end
        end
        
        def create_version
          if @picture
            self.image_versions << ImageVersion.new(:state=>"unprocessed", :priority=>5, :extension=>self.extension)
          end
        end
        
        def update_version
          if @picture
            version = self.image_versions.find(:first, :conditions=>"label is null")
            version.update_attributes(:state=>"unprocessed", :priority=>5, :extension=>self.extension)
          end
        end
              
      end
      
      module ClassMethods
        attr_accessor :convert_to, :config, :sizes, :backgroundrb, :content_type
      end
      
    end
  end
end

