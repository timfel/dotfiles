desc "installs everything"
task :install => "install:all"
namespace :install do

  def install name, *files
    desc "installs #{name} configuration"
    task(name) do
      Dir[*files].collect do |file|
        full = File.join Dir.pwd, file
        Dir.chdir ENV["HOME"] do
          mkdir_p File.dirname(file) 
          sh "ln -sf #{full} #{file}"
        end
      end
    end
    task :all => name
  end

  install :irb, ".irbrc", ".config/irb/*.rb"
  install :dot, ".bash_profile", ".bashrc", ".gemrc", ".vimrc", ".vim", ".gitignore", ".gitconfig"
  install :bin, "bin/*"
end
