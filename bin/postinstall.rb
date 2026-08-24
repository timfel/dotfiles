#!/usr/bin/env ruby

if RUBY_PLATFORM.match?(/mswin|mingw/)
  # install devkit on windows so we can build native extensions
  system "ridk install 3"
end
