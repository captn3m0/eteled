require 'sinatra'
require 'json'
require 'octokit'

load 'brain.rb'
$github = Octokit::Client.new :access_token => ENV['OAUTH_TOKEN']

set :port, ENV['PORT'] || 9393 #Default port

#Checks whether the given comment was made by a repo collaborator or not
#issue_id can be a 40 length sha1 hash as well.
def collaborator_comment?(repo, issue_id, comment_id)
	if(issue_id.length==40)
		comment = $github.commit_comment(repo, comment_id)
	else
		comment = $github.issue_comment(repo, comment_id)
	end
	user_id = comment.user.login
	collaborators=$github.collaborators(repo)
	flag = false
	#todo shorten this with a filter
	collaborators.each do |user|
		flag = true if user.login == user_id
	end
	flag
end

get '/' do
  redirect "http://captnemo.in/eteled/"
end

post '/webhook' do
	data = JSON.parse(request.body.read)
	repodata = false
	message_id=false
	#There is no "References" header for the opening comment of an issue/PR
	#Therefore, we only process if we get a References header
	data['Headers'].each do |header|
		#Get the repository and issue number via regex
		#http://www.rubular.com/r/yONKUpMQTB
		repodata = header['Value'] if header['Name']=="References"
		message_id = header['Value'] if header['Name']=="Message-ID"
	end
	return "No repository information" unless repodata
	return "No comment information" unless message_id

	
	repodata=repodata.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull|commit)\/(\S+)@github.com>/)
	repo_name = repodata[1]+"/"+repodata[2]
	issue_id = repodata[4] #This might hold the commit sha as well


	comment_details = message_id.match(/(\d+)@github.com/) #Comments always have numerical ids
	comment_id = comment_details[1]

	#Check the message
	message_body = data['TextBody'].split("\n").first.chomp
	repo_identifier = repo_name + "/" + issue_id

	#eteled Activate
	if message_body == "@eteled START"	and collaborator_comment?(repo_name, issue_id, comment_id)
		puts "Start deleting comments on #{repo_identifier}"
		Brain.add repo_identifier
		if(issue_id.length==40)
			$github.create_commit_comment repo_name, issue_id, "This thread is monitored by @eteled. Any further comments on this issue will be automatically deleted.
			Only repo collaborators can START/STOP etelde."
		else
			$github.add_comment repo_name, issue_id, "This thread is monitored by @eteled. Any further comments on this issue will be automatically deleted.
			Only repo collaborators can START/STOP etelde."
		end
		return 'START Accepted'

	#eteled De-Activate
	elsif message_body == "@eteled STOP" and collaborator_comment?(repo_name, issue_id, comment_id)
		puts "Stop deleting comments on #{repo_identifier}"
		if(issue_id.length==40)
			$github.create_commit_comment repo_name, issue_id, "This thread is no longer monitored by @eteled."
		else
			$github.add_comment repo_name, issue_id, "This thread is no longer monitored by @eteled."
		end
		Brain.delete repo_identifier
		return 'STOP Accepted'

	#if this comment is doomed for deletion
	elsif Brain.member? repo_identifier
		#We need to call different functions depending on the context
		if issue_id.length==40 #This is a commit comment
			ret = $github.delete_commit_comment(repo_name, comment_id)
		else
			ret = $github.delete_comment(repo_name, comment_id)
		end
		if ret
			puts "Deleted comment #{repo_identifier}##{comment_id}"
			return "Comment Deleted"
		else
			puts "Couldn't Delete comment #{repo_identifier}##{comment_id}"
			return "Couldn't delete comment"
		end
	#This is a normal comment, and we are not watching this thread
	else
		puts "Skipping comment #{repo_identifier}##{comment_id}"
		return "Comment untouched"
	end
	"Thanks for flying with Eteled\n"
end
