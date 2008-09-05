class ImageVersion < ActiveRecord::Base

  belongs_to :imageversionable, :polymorphic=>true
  validates_uniqueness_of :imageversionable_type, :scope => [:label, :imageversionable_id]
  
  before_save :set_extension
  after_create :pass_to_worker
  after_save :push_to_s3, :cleanup
  after_destroy :s3_destroy
  after_update :pass_to_worker_reprocess
  
    class << self
      
      def crop(source, target, width, height)
        img = Magick::Image.read(source).first
        if orientation(img) == 'landscape'
          width, height = height, width 
        end
        cropped = img.crop_resized(width, height, gravity=Magick::CenterGravity)
        cropped.write target
        GC.start
      end

      def resize_to_fit(source, target, width, height)
        img = Magick::Image.read(source).first
        if orientation(img) == 'landscape'
           width, height = height, width 
         end
        resized = img.resize_to_fit(width, height)
        resized.write target
        GC.start
      end

      # don't trust RMagick's orientation, "Exif Orientation Tag" might be missing
      # pass a Magick::Image obj
      def orientation(img)
        (img.rows > img.columns) ? "landscape" : "portrait"
      end

    end
    
  def check_connection
    unless AWS::S3::Base.connected?
      AWS::S3::Base.establish_connection!(
          :access_key_id     => imageversionable.class.config.s3['access_key_id'],
          :secret_access_key => imageversionable.class.config.s3['secret_access_key']
      )
    end
  end 
  
  def current_versions
    imageversionable.image_versions
  end

  def local_path(label='')
    label = label.blank? ? '' : "_#{label}"
    ext = pick_extension(label)
    "#{RAILS_ROOT}/tmp/s3_image/#{imageversionable.class.to_s.underscore.pluralize.downcase}/#{imageversionable.id}#{label}.#{ext}"
  end

  def versions
    imageversionable.class.sizes
  end

  def label_by_dim(width,height)
    size_versions = {}
    versions.each {|k,v| size_versions[k] = v[(0..1)] }
    size_versions.index([width,height])
  end

  def version_by_label(label)
    current_versions.find_by_label(label)
  end

  def original
    version_by_label(nil)
  end

  def s3_url(options = {})
    s3 = imageversionable.class.config.s3
    "http://" << "#{s3['bucket']}.s3.amazonaws.com" << "/" << remote_path(options)
  end

  # pass :orig=> true if you want to force remote_path to calc the original copy's uri
  def remote_path(options = {})
    config = imageversionable.class.config
    namespace =  config.env['namespace']
    deployed_to = (config.env['deployed_to'].nil?) ? '' : config.env['deployed_to'] + '/'
    label = (self.label.blank? || options[:orig]) ? '' : "_#{self.label}"
    ext = options[:orig] ? original.extension : extension
    imageversionable.class.to_s.underscore.pluralize.downcase << "/#{namespace}/#{deployed_to}#{imageversionable.id}#{label}.#{ext}"
  end

  def push_to_s3
    check_connection
    file = File.read local_path(self.label)
    logger.info "pushing #{remote_path}"
    AWS::S3::S3Object.store remote_path, file, imageversionable.class.config.s3['bucket'], :access=>:public_read
    public_grant = AWS::S3::ACL::Grant.grant :public_read
    object = AWS::S3::S3Object.find remote_path, imageversionable.class.config.s3['bucket']
    if not object.acl.grants.include? public_grant
      object.acl.grants << public_grant
      object.acl(object.acl)
    end
  end

  # will only pull the original/master-no-label image
  def pull_from_s3
    FileUtils.mkdir_p File.dirname local_path
    file = open(local_path, "wb") {|f| f << open(s3_url(:orig=>true)).read }
  end

  # pass force=true if you want to process all versions of given image
  # usually if the original was updated you'd want that, otherwise
  # if you're just adding a new size to your collection it doesn't
  # make sense processing every version there is.
  def process_versions(options = {})
    pull_from_s3 if not File.exists? local_path    
    versions.each do |k, v|
      version = version_by_label k
      next if (not options[:force]) && (not version.nil?)

      if v[2] == 'fixed'
        self.class.crop(local_path, local_path(k), v[0], v[1])
      else
        self.class.resize_to_fit(local_path, local_path(k), v[0], v[1])
      end

      unless version.nil?
        version.update_attributes(:label=>k, :state=>"processed")
      else
        imageversionable.image_versions << ImageVersion.new(:label=>k, :state=>"processed")
      end
    end
    
  end
  
  private
  
  def cleanup
    path = local_path self.label
    File.delete(path) rescue nil
  end
  
  def s3_destroy
    check_connection
    AWS::S3::S3Object.delete remote_path, imageversionable.class.config.s3['bucket']
  end
  
  def pass_to_worker
    if imageversionable.class.backgroundrb && (self.label.blank? && self.state == 'unprocessed')
      MiddleMan.new_worker :worker=>:s3_image_worker, :job_key=>self.id, :data=>{:version=>self.id}
    end
  end

  def pass_to_worker_reprocess
    if imageversionable.class.backgroundrb && (self.label.blank? && self.state == 'unprocessed')
      MiddleMan.new_worker :worker=>:s3_image_worker, :job_key=>self.id, :data=>{:version=>self.id, :force=>true}
    end
  end
  
  def pick_extension(label='')
    if label.blank?
      extension
    elsif not imageversionable.class.convert_to.blank?
      imageversionable.class.convert_to
    else
      original.extension
    end
  end
  
  def set_extension
    self.extension = pick_extension(self.label)
  end
    
end
