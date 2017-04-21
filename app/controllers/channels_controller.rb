class ChannelsController < ApplicationController
  # GET /channels
  # GET /channels.json
  def index
    @channels = Channel.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @channels }
    end
  end

  # GET /channels/1
  # GET /channels/1.json
  def show
    @channel = Channel.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @channel }
    end
  end

  # GET /channels/new
  # GET /channels/new.json
  def new
    @channel = Channel.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @channel }
    end
  end

  # GET /channels/1/edit
  def edit
    @channel = Channel.find(params[:id])
    respond_to do |format|
      format.html # new.html.erb
      format.js 
      format.json { render json: @channel }
    end

  end

  # POST /channels
  # POST /channels.json
  def create
    @channel = Channel.new(params[:channel])

    respond_to do |format|
      if @channel.save
        format.html { redirect_to @channel, notice: 'Channel was successfully created.' }
        format.json { render json: @channel, status: :created, location: @channel }
      else
        format.html { render action: "new" }
        format.json { render json: @channel.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /channels/1
  # PUT /channels/1.json
  def update
    @channel = Channel.find(params[:id])

    respond_to do |format|
      if @channel.update_attributes(params[:channel])
        format.js
        format.html { redirect_to @channel, notice: 'Channel was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @channel.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /channels/1
  # DELETE /channels/1.json
  def destroy
    @channel = Channel.find(params[:id])
    @channel.destroy

    respond_to do |format|
      format.html { redirect_to channels_url }
      format.json { head :no_content }
    end
  end

  def jqgrid_list 
    id = params[:id].to_i
    if id > 0

      index_columns ||= [:position,:sample,:detector,:ct_value,:task,:created_at]
      current_page = params[:page] ? params[:page].to_i : 1
      rows_per_page = params[:rows] ? params[:rows].to_i : 20 

      conditions={:page => current_page, :per_page => rows_per_page}
      conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)

      if params[:_search] == "true"
        conditions[:conditions]=filter_by_conditions(index_columns)
      end

      exp = SubExperiment.find(params[:id])
      entries = exp.channels.paginate(conditions)

      # filter null well
      filter_entries = []
      entries.each do |e|
        if e.sample
          filter_entries.push(e)
        end
      end

      total_entries=filter_entries.size
      total_pages = total_entries/rows_per_page.to_i + 1


      @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>filter_entries} 
    else
      @responce = {:page => 1,:total=>1 , :records =>0 , :rows=>[]} 
    end

    respond_to do |format|
      format.json { render json: @responce }
    end

  end


  def medit
    @ids = params[:id].split('_').sort
    @pos = ''
    @ids.each do |id|
      chan = Channel.find(id)
      @pos << chan.position << ','
    end
    @pos.chop!
    if @ids.size ==1
      @channel = Channel.find(@ids)
    else
      @channel = Channel.new
      @channel[:position] = @ids_str 
    end 

    channel    = Channel.find(@ids[0])
    exp_designs = channel.sub_experiment.experiment.exp_designs

    @sample_name = exp_designs.map{ |ed| [ed.sample_name,ed.sample_name] }

    render :partial => "form_medit"
  end

  def mupdate
    @ids = params[:position].split(' ')
    @par = Hash.new 
    @par[:sample]     = params[:channel][:sample]      if params[:channel][:sample] != ""
    @par[:detector]   = params[:channel][:detector]    if params[:channel][:detector] != ""
    @par[:ct_value]   = params[:channel][:ct_value]    if params[:channel][:ct_value]!= ""
    @par[:task]       = params[:channel][:task]        if params[:channel][:task]!= ""
    @par[:confidence] = params[:channel][:confidence]  if params[:channel][:confidence]!= ""
    
    if @par.size > 0
      @ids.each do |i|
        channel = Channel.find(i)
        channel.update_attributes(@par)
      end
    end
    
  end

 def edit_conf
    @channel    = Channel.find(params[:id])
    render :partial=>"form_confidence"
 end

 def update_conf
    @channel = Channel.find(params[:ids])
    @channel.update_attributes(params[:channel])
    respond_to do |format|
      format.js 
    end

 end

 def show_detector_details 
   channel = Channel.find(params[:id])
   all_channels = channel.sub_experiment.experiment.all_channel_data
   @detector_name = channel.task + ": " + channel.detector
   @channels = all_channels.select{|ch| ch.detector == channel.detector}
   @channels.sort{ |x,y| x.detector <=> y.detector}




   render :partial => "show_detector_details"

 end

end
