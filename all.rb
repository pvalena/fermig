#!/usr/bin/ruby

ROOT = File.expand_path(File.dirname(__FILE__))

PACKAGES = File.join ROOT, 'packages.rb'
USER_PACKAGES = File.join ROOT, 'user_packages.rb'
UPDATE = File.join ROOT, 'update.rb'

COMMIT_MESSAGE = %{Rebuilt for https://fedoraproject.org/wiki/Changes/Ruby_2.6}

options = {}
options[:interactive] = ARGV.include? '-i'
options[:build] = ARGV.include? '-b'
options[:user] = ARGV.include? '-u'
options[:realbuild] = ARGV.include? '-r'
options[:target] = ARGV.grep(/^\-t=./).last
options[:ignore] = ARGV.grep(/^\-i=./).last

ARGV.clear

problematic_packages = []

packages = options[:user] ? `#{USER_PACKAGES} #{options[:ignore]}` : `#{PACKAGES} #{options[:ignore]}`

exit $?.exitstatus unless $?.exitstatus.zero?

options[:target] = "--target #{options[:target][3..-1]}" if options[:target]

packages.lines do |package|
  package.chomp!

  revert = false
  quit = false

  package_dir = File.join(Dir.pwd, package)

  `fedpkg clone #{package}` unless File.exist? package_dir

  Dir.chdir package_dir do
    `git stash 2>&1`
    `git checkout master 2>&1`
    `git pull 2>&1`
    git_log = `git log --oneline -100`.chomp

    puts

    if git_log =~ /#{COMMIT_MESSAGE}/
      puts "Already converted: #{package}"
    else
      puts "Converting #{package} ... "

      `#{UPDATE} "#{package}.spec"`

      `git add -u`
      `git commit -m "#{COMMIT_MESSAGE}"`

    end

    if `git status` =~ /Your branch is ahead of 'origin\/master' by 1 commit/
      if options[:interactive]
        system 'git show HEAD'

        puts "Revert changes, quit or continue [r/q/C]?"
        answer = gets.chomp

        revert = answer =~ /r/i
        quit = answer =~ /q/i
      end

      if revert
        problematic_packages << package
        git_hash = git_log[/^(.*?) .*/, 1]
        `git reset --hard #{git_hash}`
      elsif options[:build]
        puts 'Issuing scratch build:'
        puts `fedpkg build --scratch --srpm #{options[:target]}`
        puts " => #{($?.exitstatus.zero? ? 'Succeed' : 'Failed')}"

        if $?.exitstatus.zero? && options[:realbuild]
          puts 'Issuing real build:'
          `fedpkg push`
          puts `fedpkg build #{options[:target]}`
          puts " => #{($?.exitstatus.zero? ? 'Succeeded' : 'Failed')}"
        end
      else
        puts " => Done" unless options[:interactive]
      end
    else
      puts `git status`, ' => Skipped'
    end
  end

  break if quit
end

if options[:interactive] && problematic_packages.size > 0
  puts "Reverted packages:"
  puts "=================="
  puts problematic_packages
end
