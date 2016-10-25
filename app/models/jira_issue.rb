class JiraIssue < ActiveRecord::Base
  KEY_PROJECT_NUMBER_SEPARATOR = '-'.freeze

  fields do
    key :text, limit: 255, null: false
    issue_type :text, limit: 255, null: false
    summary :text, limit: 1024, null: false
    status :text, limit: 255, null: false
    targeted_deploy_date :date, null: true
    post_deploy_check_status :text, limit: 255, null: true
    deploy_type :text, limit: 255, null: true
    timestamps
  end

  validates :key, uniqueness: { message: 'Keys must be globally unique' }
  validates :key, format: { with: /\A.+-[0-9]+\z/ }

  belongs_to :assignee, class_name: User, inverse_of: :commits, required: false
  belongs_to :parent_issue, class_name: JiraIssue, inverse_of: :sub_tasks, required: false
  has_many :sub_tasks, class_name: JiraIssue
  has_many :commits, foreign_key: 'jira_issue_id'
  has_many :jira_issues_and_pushes, class_name: :JiraIssuesAndPushes, inverse_of: :jira_issue
  has_many :pushes, through: :jira_issues_and_pushes

  class << self
    def create_from_jira_data!(jira_data)
      issue = JiraIssue.where(key: jira_data.key).first_or_initialize
      issue.summary = jira_data.summary.truncate(1024)
      issue.issue_type = jira_data.issuetype.name
      issue.status = jira_data.fields['status']['name']
      issue.targeted_deploy_date = targeted_deploy_date_from_jira_data(jira_data)
      issue.post_deploy_check_status = post_deploy_check_status_from_jira_data(jira_data)
      issue.deploy_type = deploy_type_from_jira_data(jira_data)

      if jira_data.assignee
        issue.assignee = User.create_from_jira_data!(jira_data.assignee)
      end

      if jira_data.respond_to?(:parent)
        issue.parent_issue = create_from_jira_data!(JIRA::Resource::IssueFactory.new(nil).build(jira_data.parent))
      end
      issue.save!
      issue
    end

    private

    def targeted_deploy_date_from_jira_data(jira_data)
      # TODO: extract field names to settings?
      if jira_data.fields['customfield_10600']
        Date.parse(jira_data.fields['customfield_10600'])
      end
    end

    def post_deploy_check_status_from_jira_data(jira_data)
      if jira_data.fields['customfield_12202']
        jira_data.fields['customfield_12202']['value']
      end
    end

    def deploy_type_from_jira_data(jira_data)
      if jira_data.fields['customfield_12501']
        jira_data.fields['customfield_12501'].collect do |value|
          value['value']
        end.join ', '
      end
    end
  end

  def <=>(other)
    if parent_issue && other.parent_issue
      compare_parent_keys(other)
    elsif parent_issue
      parent_issue <=> other
    elsif other.parent_issue
      self <=> other.parent_issue
    else
      compare_keys(other)
    end
  end

  def project
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[0]
  end

  def number
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[1].to_i
  end

  def compare_keys(other)
    if project == other.project
      number <=> other.number
    else
      project <=> other.project
    end
  end

  def compare_parent_keys(other)
    if parent_issue.key == other.parent_issue.key
      compare_keys(other)
    else
      parent_issue <=> other.parent_issue
    end
  end

  def latest_commit
    # TODO: add commit date to commits and sort by that instead
    commits.order('created_at ASC').first
  end
end
