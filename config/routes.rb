Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"
  resource :session, only: %i[new create destroy]
  get "u/:token", to: "sessions#restore", as: :restore
  resource :onboarding, only: %i[update]
  resource :quiniela, only: %i[show] do
    resources :predictions, only: %i[create]
  end
  resources :rankings, only: %i[index]
  resources :ligas, only: %i[index new create show edit update destroy] do
    collection { post :join }
    member { delete :leave }
  end
  delete "ligas/:id/members/:membership_id", to: "ligas#expel", as: :liga_member
  get "calendario", to: "calendar#show", as: :calendar
  get "q/:token", to: "shared_quinielas#show", as: :shared_quiniela
end
