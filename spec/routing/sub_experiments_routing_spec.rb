require "spec_helper"

describe SubExperimentsController do
  describe "routing" do

    it "routes to #index" do
      get("/sub_experiments").should route_to("sub_experiments#index")
    end

    it "routes to #new" do
      get("/sub_experiments/new").should route_to("sub_experiments#new")
    end

    it "routes to #show" do
      get("/sub_experiments/1").should route_to("sub_experiments#show", :id => "1")
    end

    it "routes to #edit" do
      get("/sub_experiments/1/edit").should route_to("sub_experiments#edit", :id => "1")
    end

    it "routes to #create" do
      post("/sub_experiments").should route_to("sub_experiments#create")
    end

    it "routes to #update" do
      put("/sub_experiments/1").should route_to("sub_experiments#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/sub_experiments/1").should route_to("sub_experiments#destroy", :id => "1")
    end

  end
end
