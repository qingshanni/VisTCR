require "spec_helper"

describe ExperimentsController do
  describe "routing" do

    it "routes to #index" do
      get("/experiments").should route_to("experiments#index")
    end

    it "routes to #new" do
      get("/experiments/new").should route_to("experiments#new")
    end

    it "routes to #show" do
      get("/experiments/1").should route_to("experiments#show", :id => "1")
    end

    it "routes to #edit" do
      get("/experiments/1/edit").should route_to("experiments#edit", :id => "1")
    end

    it "routes to #create" do
      post("/experiments").should route_to("experiments#create")
    end

    it "routes to #update" do
      put("/experiments/1").should route_to("experiments#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/experiments/1").should route_to("experiments#destroy", :id => "1")
    end

  end
end
