# http://gist.github.com/290175

# The basic idea is that we take the existing data via ActiveRecord
# and create new documents in MongoDB using MongoMapper.
# This method is necessary as we want to keep all the associations of existing dataset
# and by the way, clean up empty columns
# We rely on models still being ActiveRecord::Base, I bet you can figure out how the look like.
# And have the newer MongoDB ones here in a module, painful as we have to set the collection_name
# Don't put a +timestamps!+ into your MongoMapper models yet because this would change the updated_at if existing
# As you see in the MongoDB models, a few loose their indepence, e.g. Source as I
# plan to add other sources besides flickr, or Page and Album which only make sense in
# their parent Website
# Photo stays independed though I'm thinking about making copies into Album and Page
# as this would allow the user to change e.g. title or tags in his photos

# MongoStream is just some name as my app is called photostre.am
module MongoStream
  class Photo
    include MongoMapper::Document
    @collection_name = 'photos'
    # belongs_to :source
    # has_and_belongs_to_many :websites
    # has_and_belongs_to_many :albums
  end
  class Source
    include MongoMapper::Document
    @collection_name = 'sources'
    has_many :photos, :class_name => "MongoStream::Photo"
    # belongs_to :user
  end
  class Album
    include MongoMapper::EmbeddedDocument
    key :photo_ids, Array
    has_many :photos, :class_name => "MongoStream::Photo", :in => :photo_ids
    # belongs_to :website
    # belongs_to :key_photo, :class_name => 'Photo'
  end
  class Page
    include MongoMapper::EmbeddedDocument
    # belongs_to :website
  end
  class User
    include MongoMapper::Document
    @collection_name = 'users'
    key :website_ids, Array
    has_many :sources,  :class_name => "MongoStream::Source"
    has_many :websites, :class_name => "MongoStream::Website", :in => :website_ids
    has_many :photos, :class_name => "MongoStream::Photo"
    # has_and_belongs_to_many :websites
  end
  class Website
    include MongoMapper::Document
    @collection_name = 'websites'
    key :photo_ids, Array
    key :user_ids, Array
    has_many :albums, :class_name => "MongoStream::Album"
    has_many :pages,  :class_name => "MongoStream::Page"
    has_many :photos, :class_name => "MongoStream::Photo", :in => :photo_ids
    has_many :users,  :class_name => "MongoStream::User", :in => :user_ids
    # has_and_belongs_to_many :users
  end
end

class MigrateToMongodb < ActiveRecord::Migration
  require 'mongo_mapper'
  def self.clean_attrs(object, unneeded_attributes = [])
    unneeded_attributes << 'id'
    attributes = object.attributes.dup
    # we keep the old_id for now to copy the associations much easier
    attributes['old_id'] = attributes['id']
    attributes.reject!{|k,v|unneeded_attributes.include?(k.to_s) || v.nil?}
    attributes
  end
  def self.up
    %w(MongoStream::User MongoStream::Website MongoStream::Photo MongoStream::Source).map{|klass| instance_eval("#{klass}.delete_all") rescue nil }
    ::User.all.each do |user|
      m_user = MongoStream::User.create!(clean_attrs(user))

      user.sources.find(:all, :limit => 10).each do |source|
        m_source = MongoStream::Source.new(clean_attrs(source))
        m_source[:user_id] = m_user.id
        source.photos.each do |photo|
          m_photo = MongoStream::Photo.create!(clean_attrs(photo))
          m_photo[:tags] = photo.tag_list.to_a
          m_photo[:source_id] = m_source.id
          m_photo[:user_id] = m_source.user_id
          m_photo.save
        end
        m_source.save
        m_user.sources << m_source
      end
      # With those embedded documents, never forget to save the root element!
      m_user.save
    end
    Website.all.each do |website|
      m_website = MongoStream::Website.create(clean_attrs(website))
      m_website.photos = MongoStream::Photo.all(:conditions => {:old_id => website.photo_ids})
      m_website.user_ids = MongoStream::User.all(:conditions => {:old_id => website.user_ids}).collect(&:_id)
      website.albums.each do |album|
        m_website.albums << MongoStream::Album.new(clean_attrs(album, %w(website_id key_photo_id parent_id)))
      end
      website.pages.each do |page|
        m_website.pages << MongoStream::Page.new(clean_attrs(page, %w(website_id user_id parent_id)))
      end
      m_website.save
    end
    # And now again all users and update their website_ids
    MongoStream::User.all.each do |m_user|
      old_website_ids = User.find(m_user.old_id).website_ids
      m_user.update_attribute(:website_ids, MongoStream::Website.all(:conditions => {:old_id => old_website_ids}).collect(&:id))
    end

    # The best is to clean up and remove the old_ids via the mongo console, there for mongo 1.3+
    #   db.photos.update({}, { $unset : { old_id : 1}}, false, true )
    #   db.websites.update({}, { $unset : { old_id : 1, 'albums.old_id': 1, 'pages.old_id': 1}}, false, true )
    #   db.users.update({}, { $unset : { old_id : 1}}, false, true )
    
  end

  def self.down
  end
end
