# http://gist.github.com/293059

class Post
  key :title, String
  key :slug, String

  validates_presence_of :title, :slug
  validates_uniqueness_of :slug
  before_create :fill_in_slug

protected
  def fill_in_slug
    self.slug ||= self.title.parameterize unless self.title.blank?
  end
end