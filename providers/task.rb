#
# Author:: Paul Mooring (<paul@chef.io>)
# Cookbook Name:: windows
# Provider:: task
#
# Copyright:: 2012, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use_inline_resources

def whyrun_supported?
  true
end

action :create do
  create_or_update_task :create
end

action :run do
  windows_advanced_task new_resource.task_name do
    action :start
  end
end

action :change do
  create_or_update_task :update
end

action :delete do
  windows_advanced_task new_resource.task_name do
    action :delete
  end
end

action :end do
  windows_advanced_task new_resource.task_name do
    action :stop
  end
end

action :enable do
  windows_advanced_task new_resource.task_name do
    action :enable
  end
end

action :disable do
  windows_advanced_task new_resource.task_name do
    action :disable
  end
end

private

DAYS_VALUE = { 'SUN' => 1, 'MON' => 2, 'TUE' => 4, 'WED' => 8, 'THU' => 16, 'FRI' => 32, 'SAT' => 64, '*' => '127' }
TRIGGER_MAP = { once: :time, minute: :time, hourly: :time, on_logon: :logon, onstart: :boot, on_idle: :idle }

def formated_start_boundary
  day = new_resource.start_day || DateTime.now.strftime('%d/%m/%Y')
  time = new_resource.start_time || DateTime.now.strftime('%H:%M')

  DateTime.strptime("#{day} #{time}", '%d/%m/%Y %H:%M').strftime('%Y-%m-%dT%H:%M:%S')
end

def create_or_update_task(chef_action)
  # can't call below helpers from the windows_advanced_task block
  trigger = compute_trigger
  logon_type = compute_logon_type
  exec_action = compute_exec_action

  windows_advanced_task new_resource.task_name do
    action        chef_action
    exec_actions  exec_action
    force         new_resource.force
    logon_type    logon_type
    password      new_resource.password if [:interactive_token_or_password, :password].include?(logon_type)
    run_level     new_resource.run_level
    triggers      trigger
    user          new_resource.user
  end
end

def compute_exec_action
  # Splits path and arguments from given command
  path, args = new_resource.command.match(/("[^"]+"|[^"\s]+)\s*(.*)/).captures
  Windows::TaskSchedulerHelper.new_ole_hash :exec_action, 'Arguments' => args, 'Path' => path, 'WorkingDirectory' => new_resource.cwd
end

def compute_day_of_week_value(days)
  case days
    when String
      days.upcase.split(',').inject(0) do |mask, day|
        fail 'Invalid day attribute, valid values are: MON, TUE, WED, THU, FRI, SAT, SUN and *. Multiple values must be separated by a comma.' unless DAYS_VALUE.key? day
        mask | DAYS_VALUE[day]
      end
    else
      days
  end
end

def compute_logon_type
  if Windows::TaskSchedulerHelper::SERVICE_USERS.include?(@new_resource.user.upcase)
    :service_account
  else
    fail 'Password is mandatory when using interactive mode or non-system user!' if new_resource.password.nil?
    new_resource.interactive_enabled ? :interactive_token_or_password : :password
  end
end

def compute_trigger
  fail 'Days should only be used with weekly or monthly frequency' if new_resource.day && [:weekly, :monthly].include?(new_resource.frequency)

  {}.tap do |trigger|
    # Format StartBoundary if start_day or start_time is provided
    trigger['StartBoundary'] = formated_start_boundary unless new_resource.start_day.nil? && new_resource.start_time.nil?

    # Converts frequency to advanced_task trigger type
    trigger['Type'] = TRIGGER_MAP[new_resource.frequency] || new_resource.frequency

    case new_resource.frequency
      when :daily then trigger['DaysInterval'] = new_resource.frequency_modifier
      when :hourly then trigger['Repetition'] = { 'Interval' => "PT#{new_resource.frequency_modifier}H" }
      when :minute then trigger['Repetition'] = { 'Interval' => "PT#{new_resource.frequency_modifier}M" }
      when :on_logon then trigger['UserId'] = new_resource.user
      when :weekly
        trigger['WeeksInterval'] = new_resource.frequency_modifier
        trigger['DaysOfWeek'] = compute_day_of_week_value
      when :monthly
        trigger['DaysInterval'] = new_resource.frequency_modifier
        trigger['DaysOfMonth'] = new_resource.day
    end
  end
end
