Qpcr::Application.routes.draw do

  resources :projects do
    member {
    }
    collection {
      get :jqgrid_list
      get :delete_recorder
    }
  end 



  resources :samples do
    member {
    }
    collection {
      get :jqgrid_list
      get :delete_recorder
      get :qc_analysis
      get :json_qc_fig_data
      get :download_sample_data
      get :download_ref_file
      get :download_ref_file_default
    }
  end 


  resources :sub_experiments do
    member {
    }
    collection {
      get  :jqgrid_list
      get  :delete_recorder
      get  :sample_details
      get  :form_new_sample
      post :new_sample
      get  :form_rename_sample
      post :rename_sample
      get  :del_sample
      get  :form_upload_sample_file
      post :upload_sample_file
      get :del_sample_file
      get :download_sample_file

      get :qc_analysis
      get :json_qc_fig_data
     
      get :single_sample_tcr_analysis
      get :json_fig_single_sample_tcr_analysis



      get :show_mitcr_result

      get :segment_statics
      get :json_segment_statics

      get :trbv_usage
      get :json_trbv_usage
      get :json_trbj_usage

      get :trbj_usage
      get :json_trbj_usage




      get :vj_segment_statics
      get :json_vj_segment_statics

      get :cdr3_spectratype
      get :json_cdr3_spectratype

      get :cumulative_clonotype
      get :json_cumulative_clonotype

      get :clonotypes_frequency
      get :json_clonotypes_frequency

      get :download_sub_exp_data
    }
  end

  resources :experiments do
    member {
    }
    collection {
      get :jqgrid_list
      get :delete_recorder
      get :jqgrid_exp_design_list

      get :experiment_detail
      get :experiment_detail_design
      get :form_set_experiment
      post :set_experiment_params

      get :extract_clone
      get :downlaod_exp_design
    
      get :form_pairwaise_analysis_params
      get :show_pairwaise_analysis_params

      get :pairwaise_analysis
      get :json_fig_pairwaise_analysis

      get :form_whole_tcr_analysis
      post :whole_tcr_analysis
      get :json_whole_tcr_analysis
    }
  end

  authenticated :user do
    root :to => 'experiments#index'
  end
  root :to => "users#index"
  devise_for :users
  resources :users
end
