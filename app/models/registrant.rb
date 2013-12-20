class Registrant < ActiveRecord::Base
  has_many :registrations
  has_many :events, :through => :registrations
  belongs_to :user
  has_many :charges
  has_many :memberships
  has_many :groups, :through => :memberships

  def balance
    self.charges.count > 0 ? self.charges.map{|c| c.amount || 0}.inject(0, :+) : 0
  end

  def waiting_on? event
      registrations.where(:event_id => event.id).first.waiting
  end
end