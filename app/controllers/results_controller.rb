require 'lib/repo/repository_factory'
class ResultsController < ApplicationController
  before_filter      :authorize_only_for_admin, :except => [:codeviewer, :edit, :update_mark, :view_marks, :create, :add_extra_mark, :download]
  before_filter      :authorize_for_ta_and_admin, :only => [:edit, :update_mark, :create, :add_extra_mark, :download]
  before_filter      :authorize_for_user, :only => [:codeviewer]
  before_filter      :authorize_for_student, :only => [:view_marks]

  def create
    # Create new Result for this Submission
    @submission_id = params[:id]
    @submission = Submission.find(@submission_id)
    
    # Is there already a result for this Submission?
    if @submission.has_result?
      # If so, our new Result needs to have a version number greater than the
      # old result version.  We're also going to set this new result to be current.
      old_result = @submission.get_result_used
      old_version_number = old_result.result_version
      new_version_number = old_version_number + 1
      old_result.result_version_used = false
      old_result.save
    else
      new_version_number = 1
    end
    
    new_result = Result.new
    new_result.submission = @submission
    new_result.marking_state = Result::MARKING_STATE[:partial]
    new_result.save
    redirect_to :action => 'edit', :id => new_result.id
  end
  
  def index
  end
  
  def edit
    result_id = params[:id]
    @result = Result.find(result_id)
    @assignment = @result.submission.assignment
    @rubric_criteria = @assignment.rubric_criteria
    @submission = @result.submission
    @annotation_categories = @assignment.annotation_categories
    @grouping = @result.submission.grouping
    @group = @grouping.group
    @files = @submission.submission_files
    @first_file = @files.first
    @extra_marks = @result.extra_marks
    @marks_map = []
    @rubric_criteria.each do |criterion|
      mark = Mark.find_or_create_by_result_id_and_rubric_criterion_id(@result.id, criterion.id)
      mark.save(false)
      @marks_map[criterion.id] = mark
    end
    
  end
  
  def download
    file = SubmissionFile.find(params[:select_file_id])
    begin
      file_contents = retrieve_file(file)
    rescue Exception => e
      # TODO:  Make this more graceful (#164)
      flash[:file_download_error] = e.message
      redirect_to :action => 'edit', :id => file.submission.result.id
      return
    end
    send_data file_contents, :disposition => 'inline', :filename => file.filename
  end
  
  def codeviewer
    @assignment = Assignment.find(params[:id])
    @submission_file_id = params[:submission_file_id]
      
    file = SubmissionFile.find(@submission_file_id)
    # Is the current user a student?
    if current_user.student?
      # The Student does not have access to this file.  Render nothing.
      if file.submission.grouping.membership_status(current_user).nil?
        raise "No access to submission file with id #{@submission_file_id}"
      end
    end

    annots = Annotation.find_all_by_submission_file_id(@submission_file_id, :order => "line_start") || []
    begin
      file_contents = retrieve_file(file)
    rescue Exception => e
      render :update do |page|
        page.call "alert", e.message
      end
      return
    end   
    
    # Is this file a binary?
#    if SubmissionFile.is_binary?(file_contents)
#      render :update do |page|
#        page.redirect_to :action => 'download', :submission_file_id => @submission_file_id
#      end
#      return
#    end
    
    @code_type = file.get_file_type
    
    render :update do |page|
      #Render the source code for syntax highlighting...
      begin
        page.replace_html 'codeviewer', :partial => 'results/common/codeviewer', :locals => 
        { :uid => params[:uid], :file_contents => file_contents, :annots => annots, :code_type => @code_type}
      #Also update the annotation_summary_list
        page.replace_html 'annotation_summary_list', :partial => 'annotations/annotation_summary', :locals => {:annots => annots, :submission_file_id => @submission_file_id}
      rescue
        # There's a bug in Rails as of 2.3.2 - #1112 - some binary strings
        # will result in a "redundant UTF-8 sequence" error when attempting
        # to convert to JSON.  This is scheduled for fixing in Rails 2.3.4.
        # Until then, we'll just ask the user to download the file.
        
        # TODO:  Make this more graceful, and localized
        page.call "alert", "Could not render this file in the code viewer.  Click on the Download button to download the file instead."
      end
    end    
  end
  
  def update_mark
    result_mark = Mark.find(params[:mark_id])
    mark_value = params[:mark]
    result_mark.mark = mark_value
    if !result_mark.save
      render :update do |page|
        page.call 'alert', 'Could not save this mark!: ' + result_mark.errors
      end
    else
      render :update do |page|
        page.call 'select_mark', result_mark.id, mark_value
        page.replace_html "rubric_criterion_title_#{result_mark.id.to_s}_mark", "<b> #{result_mark.mark} #{result_mark.rubric_criterion["level_" + result_mark.mark.to_s + "_name"]}</b> #{result_mark.rubric_criterion["level_" + result_mark.mark.to_s + "_description"]}"
        page.replace_html "mark_#{result_mark.id.to_s}_summary_mark", result_mark.mark
        page.replace_html "mark_#{result_mark.id.to_s}_summary_mark_after_weight", (result_mark.mark * result_mark.rubric_criterion.weight)
        page.replace_html "current_subtotal_div", result_mark.result.get_subtotal
        page.replace_html "current_total_mark_div", result_mark.result.total_mark
      end
    end
  end
  
  def view_marks
    @assignment = Assignment.find(params[:id])
    @grouping = current_user.accepted_grouping_for(@assignment.id)
    if !@grouping.has_submission?
      render 'results/student/no_submission'
      return
    end
    @submission = @grouping.get_submission_used
    if !@submission.has_result?
      render 'results/student/no_result'
      return
    end
    @result = @submission.result
    if !@result.released_to_students
      render 'results/student/no_result'
      return
    end
    @rubric_criteria = @assignment.rubric_criteria
    @annotation_categories = @assignment.annotation_categories
    @group = @grouping.group
    @files = @submission.submission_files
    @first_file = @files.first
    @extra_marks = @result.extra_marks
    @marks_map = []
    @rubric_criteria.each do |criterion|
      mark = Mark.find_or_create_by_result_id_and_rubric_criterion_id(@result.id, criterion.id)
      mark.save(false)
      @marks_map[criterion.id] = mark
    end
  end
  

  #Adds a new extra mark object and inserts it into the html
  def add_extra_mark
    extra_mark = ExtraMark.new(params[:extra_mark])
    extra_mark.save
    render :update do |page|
      #insert the new mark into the bottom of the table and focus it
      page.insert_html :bottom, "extra_marks_list",
        :partial => "results/common/extra_mark", :locals => { :mark => extra_mark }
      page.call(:focus_extra_mark, extra_mark.id.to_s)
    end
  end

  #Deletes an extra mark from the database and removes it from the html
  def remove_extra_mark
    #find the extra mark and destroy it
    extra_mark = ExtraMark.find(params[:mark_id])
    extra_mark.destroy
    #need to recalculate total mark
    result = Result.find(extra_mark.result_id)
    result.calculate_total
    render :update do |page|
      #delete it from the html
      page.remove("extra_mark_#{params[:mark_id]}")
      page.replace_html("current_total_mark_div", result.total_mark)
    end
  end

  #update the mark and/or description of the extra mark
  def update_extra_mark
    extra_mark = ExtraMark.find(params[:id])
    #the attribute to be changed - description or mark
    type = params[:type]
    #the new attribute value
    val = params[:value]
    #change the value
    extra_mark[type] = val

    #save it
    if extra_mark.valid? && extra_mark.save
      #need to update the total mark
      result = Result.find(extra_mark.result_id)
      result.calculate_total
      render :update do |page|
        #The following divs need to be changed
        #1 the display of the extra mark
        page.replace_html("extra_mark_title_#{extra_mark.id}_" + type, val)
        #2 the display of the total mark
        page.replace_html("current_total_mark_div", result.total_mark)
        #3 the divs containing deductions/bonuses
        page.replace_html("extra_marks_bonus", result.get_bonus_marks)
        page.replace_html("extra_marks_deducted", result.get_deductions)
        #4 the div containing the total mark at the top of the page
        page.replace_html("current_mark_div", result.total_mark)
      end
    else
      output = {'status' => 'error'}
      render :json => output.to_json
    end
  end
  
  private
  
  def retrieve_file(file)
    student_group = file.submission.grouping.group
    repo = Repository.create(REPOSITORY_TYPE).new(File.join(REPOSITORY_STORAGE, student_group.repository_name))
    revision_number = file.submission.revision_number
    revision = repo.get_revision(revision_number)
    if revision.files_at_path(file.path)[file.filename].nil?
      raise "Could not find #{file.filename} in repository #{student_group.repository_name}"
    end
    return repo.download(revision.files_at_path(file.path)[file.filename])
  end
  
end