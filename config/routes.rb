# frozen_string_literal: true

DiscourseResourcesHtml::Engine.routes.draw do
  get "/resources" => "resources#show"
end
