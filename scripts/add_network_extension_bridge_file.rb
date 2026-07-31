#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.expand_path('../../macos/Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

runner_group = project.main_group.find_subpath('Runner', false)
raise 'Runner group not found' unless runner_group

file_name = 'NetworkExtensionBridge.swift'
if runner_group.files.find { |f| f.path == file_name }
  puts "#{file_name} already registered, skipping."
else
  file_ref = runner_group.new_file(file_name)
  runner_target.add_file_references([file_ref])
  puts "Added #{file_name} to Runner target."
end

project.save
