# http://gist.github.com/293833

class Comment
  include MongoMapper::Document
  
  key :poll_id, Integer, :required => true, :index => true
  key :name,    String, :required => true
  key :email,   String, :required => true
  key :body,    String, :required => true
  timestamps!
  
  def poll
    @poll ||= Poll.find(poll_id)
  end
  
  def poll=(poll)
    @poll = nil
    self.poll_id = poll.id unless poll.blank?
  end
end

class Poll < ActiveRecord::Base
  def comments
    Comment.find_all_by_poll_id(id)
  end
end