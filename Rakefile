desc "installs everything"
task :install => "install:all"
namespace :install do

  def _install name, *files
    desc "installs #{name} configuration"
    task(name) do
      Dir[*files].collect do |file|
        full = File.join Dir.pwd, file
        Dir.chdir ENV["HOME"] do
          mkdir_p File.dirname(file)
          sh "rm #{file}" if (File.exist? file and File.directory? full)
          Dir.chdir File.join(ENV["HOME"], File.dirname(file)) do
            if Dir.pwd == ENV["HOME"] or Dir.pwd == "#{ENV["HOME"]}/"
              relative = full.sub(ENV["HOME"], "")
              relative = relative[1..-1] while relative.start_with? "/"
            else
              relative = File.join("../" * File.dirname(file).split("/").size, full.sub(ENV["HOME"], ""))
            end
            sh "ln -sf #{relative} #{File.basename(file)}"
          end
        end
      end
    end
    task :all => name
  end

  _install :irb, ".irbrc", ".config/irb/*.rb"
  _install :dot, ".bash_profile", ".bashrc", ".gemrc", ".vimrc", ".vim", ".hgrc",
           ".gitignore", ".gitconfig", ".ssh/config", ".config/nv-*", ".Color*.icc",
           ".tmux.conf", ".tmux.bashrc", ".topazini", ".Xresources", ".screenrc",
           ".stumpwmrc", ".i3", ".pdbrc", ".xbindkeysrc", ".pine-passfile", ".pinerc",
           ".xinitrc", ".gdbinit", ".mambarc", ".docker/config.json"
  _install :bin, "bin/*"

  desc "installs the custom texmf folder"
  task :texmf do
    sh "git submodule init && git submodule update"
    _install :texmf_folder, "texmf"
    Rake::Task[:texmf_folder].invoke
  end

  task :all => :texmf

end
