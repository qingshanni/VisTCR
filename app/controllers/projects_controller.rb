class ProjectsController < ApplicationController
  layout "tcr_data"
  # GET /projects
  # GET /projects.json
  def index
    respond_to do |format|
      if current_user
        format.html # index.html.erb
      else
        format.html { redirect_to root_path}
      end
    end
 end


  # GET /projects/1
  # GET /projects/1.json
  def show
    @project = Project.find(params[:id])
    render :partial => 'details'
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    @project = Project.new
    render :partial => 'form'
  end

  # GET /samples/1/edit
  def edit
    @project = Project.find(params[:id])
    render :partial => 'form'
  end


  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(params[:project])
    @project.user_id = current_user.id
    @project.save
 end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    @project = Project.find(params[:id])
    @project.update_attributes(params[:project])
 end


  def delete_recorder
    @project = Project.find(params[:id])
    @project.destroy

    render  :text=>'Delete success !' 
  end

  def jqgrid_list 
    
    index_columns ||= [:title, :created_at]
    current_page  = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 20 

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
    
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end

    @entries = current_user.projects.paginate(conditions)
   
   total_entries = @entries.total_entries
   total_pages   = total_entries/rows_per_page.to_i + 1

   @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 

    respond_to do |format|
      format.json { render json: @responce }
    end

  end




end
