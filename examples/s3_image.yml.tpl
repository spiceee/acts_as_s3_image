s3:
    access_key_id: 
    secret_access_key: 
    bucket: 
app:
    # not used for now
    state_model: image_version
---
# these params will add up to your a3 uri to protect enviroment clashes of ids and images
# so your s3 images will have a uri #{bucket}/#{act_as_s3_image_model_name}/#{namespace}/#{deployed_to}/#{id}.#{ext}
# only deployed_to is optional, it won't show in the uri if it's omitted
# we have yet to implement a rake task that would change uris if you change namespace, at this point this is rather
# fixed so think about this before you start using this plugin
development:
    namespace: d

production:
    namespace: p
    deployed_to: staging
    
