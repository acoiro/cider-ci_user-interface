#  Copyright (C) 2013, 2014 Dr. Thomas Schank  (DrTom@schank.ch, Thomas.Schank@algocon.ch)
#  Licensed under the terms of the GNU Affero General Public License v3.
#  See the LICENSE.txt file provided with this software.

class PublicController < ApplicationController

  include Concerns::ServiceSession
  include Concerns::BadgeParamsBuilder
  include ActionView::Helpers::TextHelper


  def show
    @radiator_rows= 
      begin 
        WelcomePageSettings.find
        .radiator_config.try(:[],"rows").map do |row|
          {name: row.try(:[],"name"),
           items: build_items(row) }
        end
      rescue Exception => e
        Rails.logger.warn ["Failed to parse radiator config",Formatter.exception_to_log_s(e)]
        flash["error"]="Failed to build the radiator, see the logs for details."
        []
      end
  end

  def build_items row
    row.try(:[],"items").map(&:deep_symbolize_keys).map do |item|
      build_badge_params item[:repository_name], item[:branch_name], item[:execution_name]
    end
  end

  def find_user_by_login login
    begin
      User.find_by(login_downcased: login) || EmailAddress.find_by!(email_address: login).user
    rescue
      raise "Neither login nor email found!"
    end
  end


  def sign_in
    begin
      user = find_user_by_login params.require(:sign_in)[:login].downcase
      target_path= (params[:current_fullpath] || public_path)
      if user.authenticate(params.require(:sign_in)[:password])
        create_services_session_cookie user
        redirect_to target_path, 
          flash: {success: "You have been signed in!"}
      else
        reset_session
        cookies.delete "cider-ci_services-session"
        raise "Password authentication failed!"
      end
    rescue Exception => e
      reset_session
      cookies.delete "cider-ci_services-session"
      redirect_to (target_path || public_path), flash: {error: e.to_s}
    end
  end


  def sign_out
    reset_session
    cookies.delete "cider-ci_services-session"
    redirect_to (params[:current_fullpath] || public_path), 
      flash: {success: "You have been signed out!"}
  end


  def redirect_to_execution
    if @execution = Execution.find_by_repo_branch_name( \
      params[:repository_name],  params[:branch_name], params[:execution_name])
      redirect_to workspace_execution_path(@execution)
    else
      flash[:warning]= [%<You are looking for the execution "#{params[:execution_name]}">,
        %<of the branch "#{params[:branch_name]}" >, %<and the repository "#{params[:repository_name]}". >,
        "It doesn't exist at this time. You can try again later."].join("")
      render "public/404", status: 404
    end
  end

# http://localhost:8880/cider-ci/ui/public/attachments/Cider-CI%20Bash%20Demo%20Project/master/tests/log/hello.log
   
  def redirect_to_tree_attachment_content
    if @execution = Execution.find_by_repo_branch_name(params[:repository_name], 
                     params[:branch_name], params[:execution_name])
      if  tree_attachment = TreeAttachment.find_by(path: "/#{@execution.tree_id}/#{params[:path]}") 
        redirect_to workspace_attachment_path('tree_attachment',tree_attachment.path) 
      else
        flash[:warning]= [%<You are looking for the attchment `#{params[:path]}` >,
                          %<with the tree-id `#{truncate(@execution.tree_id, length: 10)}`. >,
                          "It doesn't exist at this time. You can try again later."].join("")
        render "public/404", status: 404
      end
    else
      flash[:warning]= [%<You are looking for the execution "#{params[:execution_name]}">,
        %<of the branch "#{params[:branch_name]}" >, %<and the repository "#{params[:repository_name]}". >,
        "It doesn't exist at this time. You can try again later."].join("")
      render "public/404", status: 404
    end
  end



end
