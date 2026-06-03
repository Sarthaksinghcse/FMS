require 'xcodeproj'
project_path = 'FMS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath('FMS', true)
file_ref = group.new_reference('splash_video.mp4')
target.add_resources([file_ref])
project.save
