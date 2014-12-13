#  Copyright (C) 2013, 2014 Dr. Thomas Schank  (DrTom@schank.ch, Thomas.Schank@algocon.ch)
#  Licensed under the terms of the GNU Affero General Public License v3.
#  See the LICENSE.txt file provided with this software.

class Task < ActiveRecord::Base
  self.primary_key= 'id'
  before_create{self.id ||= SecureRandom.uuid}
  belongs_to :execution
  has_many :trials

  belongs_to :task_spec

  validates :state, inclusion: {in: Constants::TASK_STATES}

  default_scope{order(created_at: :desc,id: :asc)}

  scope :with_failed_trials, lambda{
    where("EXISTS (SELECT 1 FROM trials WHERE trials.task_id = tasks.id AND trials.state = 'failed')")
  }


  def to_s
    name
  end
end
