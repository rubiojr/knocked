require 'rake'

task :gem => [:clean_gem, :make_gem, :mv_gem] do
end

task :make_gem do
  `gem build *.gemspec`
end

task :mv_gem do
  `mv *.gem build/`
end

task :clean_gem do
  `rm build/*.gem`
end

task :gem_install => [:gem] do
  `gem install build/*.gem`
end

task :publish_gem do
  `scp build/*.gem root@slmirror.csic.es:/espejo/rubygems/gems/`
  `ssh slmirror gem generate_index -d /espejo/rubygems/`
end

task :clean => [:clean_gem]
