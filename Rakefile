unless File.respond_to? :realpath
  class File
    def self.realpath path
      return realpath(readlink(path)) if symlink?(path)
      path
    end
  end
end

task :install_files, [:folder] do |t, args|
  args.with_defaults :folder => ENV['HOME']

  files = Dir[File.join File.dirname(__FILE__), 'files/{.*,*}']
  files += Dir[File.join File.dirname(__FILE__), 'private/files/{.*,*}']
  files.delete_if { |file| /\/\.$/ =~ file or /\/\.\.$/ =~ file }
  files.each do |file|
    new_file = File.join args[:folder], File.basename(file)

    unless File.exists?(new_file) and File.realpath(new_file) == File.realpath(file)
      if File.exists? new_file or File.symlink? new_file
        i = 0; backup_file = new_file + '.backup'
        (i += 1; backup_file = new_file + ".backup#{i}") while File.exists? backup_file

        puts "Making backup of [#{new_file}] at [#{backup_file}]"
        FileUtils.mv new_file, backup_file
      end

      puts "Symlinking [#{file}] to [#{new_file}]"
      File.symlink file, new_file
    end
  end
end

task :install_vundle do |t|
  bundle_folder = File.join ENV['HOME'], '.vim/bundle'
  vundle_folder = File.join bundle_folder, 'vundle'
  Dir.mkdir bundle_folder unless File.exists? bundle_folder
  system "git clone git://github.com/gmarik/vundle.git #{vundle_folder}" unless File.exists? vundle_folder
  system "vim -c 'BundleInstall' -c 'qa'"
end

task :install => [:install_files, :install_vundle]
