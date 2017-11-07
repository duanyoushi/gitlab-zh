require 'spec_helper'

feature 'Clusters', :js do
  include GoogleApi::CloudPlatformHelpers

  let!(:project) { create(:project, :repository) }
  let!(:user) { create(:user) }

  before do
    project.add_master(user)
    gitlab_sign_in(user)
  end

  context 'when user has signed in Google' do
    before do
      allow_any_instance_of(Projects::ClustersController)
        .to receive(:token_in_session).and_return('token')
      allow_any_instance_of(Projects::ClustersController)
        .to receive(:expires_at_in_session).and_return(1.hour.since.to_i.to_s)
    end

    context 'when user does not have a cluster and visits cluster index page' do
      before do
        visit project_clusters_path(project)
      end

      it 'user sees a new page' do
        expect(page).to have_button('Create cluster')
      end

      context 'when user filled form with valid parameters' do
        before do
          double.tap do |dbl|
            allow(dbl).to receive(:status).and_return('RUNNING')
            allow(dbl).to receive(:self_link)
              .and_return('projects/gcp-project-12345/zones/us-central1-a/operations/ope-123')
            allow_any_instance_of(GoogleApi::CloudPlatform::Client)
              .to receive(:projects_zones_clusters_create).and_return(dbl)
          end

          allow(WaitForClusterCreationWorker).to receive(:perform_in).and_return(nil)

          fill_in 'cluster_provider_gcp_attributes_gcp_project_id', with: 'gcp-project-123'
          fill_in 'cluster_name', with: 'dev-cluster'
          click_button 'Create cluster'
        end

        it 'user sees a cluster details page and creation status' do
          expect(page).to have_content('Cluster is being created on Google Container Engine...')

          Clusters::Cluster.last.provider.make_created!

          expect(page).to have_content('Cluster was successfully created on Google Container Engine')
        end
      end

      context 'when user filled form with invalid parameters' do
        before do
          click_button 'Create cluster'
        end

        it 'user sees a validation error' do
          expect(page).to have_css('#error_explanation')
        end
      end
    end

    context 'when user has a cluster and visits cluster index page' do
      let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
      let(:project) { cluster.project }

      before do
        visit project_clusters_path(project)
      end

      it 'user sees an cluster details page' do
        expect(page).to have_button('Save')
        expect(page.find(:css, '.cluster-name').value).to eq(cluster.name)
      end

      context 'when user disables the cluster' do
        before do
          page.find(:css, '.js-toggle-cluster').click
          click_button 'Save'
        end

        it 'user sees the succeccful message' do
          expect(page).to have_content('Cluster was successfully updated.')
        end
      end

      context 'when user destory the cluster' do
        before do
          page.accept_confirm do
            click_link 'Remove integration'
          end
        end

        it 'user sees creation form with the succeccful message' do
          expect(page).to have_content('Cluster integration was successfully removed.')
          expect(page).to have_button('Create cluster')
        end
      end
    end
  end

  context 'when user has not signed in Google' do
    before do
      visit project_clusters_path(project)
    end

    it 'user sees a login page' do
      expect(page).to have_css('.signin-with-google')
    end
  end
end