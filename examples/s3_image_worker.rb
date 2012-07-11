# backgroundrb worker
# see http://backgroundrb.rubyforge.org/

class S3ImageWorker < BackgrounDRb::MetaWorker
  set_worker_name :s3_image_worker

  # pass :force=>true if you need every version of an image to be reprocessed, ie on an update of the image file
  # otherwise process_versions only act on versions/sizes that don't already exist
  def create(options={})
    logger.info "processing image #{options[:version]}"

    version = ImageVersion.find(options[:version], :lock=>true)
    options[:force] ? version.process_versions(:force=>true) : version.process_versions
    version.state = 'processed'
    version.save!
  end

end

