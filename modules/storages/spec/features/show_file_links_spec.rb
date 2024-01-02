# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'
require_module_spec_helper

RSpec.describe 'Showing of file links in work package', js: true do
  let(:permissions) { %i(view_work_packages edit_work_packages view_file_links manage_file_links) }
  let(:project) { create(:project) }
  let(:current_user) { create(:user, member_with_permissions: { project => permissions }) }
  let(:work_package) { create(:work_package, project:, description: 'Initial description') }

  let(:oauth_application) { create(:oauth_application) }
  let(:storage) { create(:nextcloud_storage, oauth_application:) }
  let(:oauth_client) { create(:oauth_client, integration: storage) }
  let(:oauth_client_token) { create(:oauth_client_token, oauth_client:, user: current_user) }
  let(:project_storage) { create(:project_storage, project:, storage:) }
  let(:file_link) { create(:file_link, container: work_package, storage:) }
  let(:wp_page) { Pages::FullWorkPackage.new(work_package, project) }

  let(:connection_manager) { instance_double(OAuthClients::ConnectionManager) }
  let(:sync_service) { instance_double(Storages::FileLinkSyncService) }

  before do
    allow(OAuthClients::ConnectionManager)
      .to receive(:new)
            .and_return(connection_manager)
    allow(connection_manager)
      .to receive_messages(refresh_token: ServiceResult.success(result: oauth_client_token),
                           get_access_token: ServiceResult.success(result: oauth_client_token),
                           authorization_state: :connected)

    # Mock FileLinkSyncService as if Nextcloud would respond with origin_permission=nil
    allow(Storages::FileLinkSyncService)
      .to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:call) do |file_links|
      ServiceResult.success(result: file_links.each { |file_link| file_link.origin_permission = :view })
    end

    project_storage
    file_link

    login_as current_user
    wp_page.visit_tab! :files
  end

  context 'if work package has associated file links' do
    it "must show associated file links" do
      expect(page).to have_test_selector('op-tab-content--tab-section', count: 2)
      within_test_selector('file-list') do
        expect(page).to have_test_selector('file-list--item', text: file_link.origin_name, count: 1)
      end
    end
  end

  context 'if user has no permission to see file links' do
    let(:permissions) { %i(view_work_packages edit_work_packages) }

    it 'must not show a file links section' do
      expect(page).to have_test_selector('op-tab-content--tab-section', count: 1)
    end
  end

  context 'if project has no storage' do
    let(:project_storage) { {} }

    it 'must not show a file links section' do
      expect(page).to have_test_selector('op-tab-content--tab-section', count: 1)
    end
  end

  context 'if user is not authorized in Nextcloud' do
    before do
      allow(connection_manager).to receive_messages(authorization_state: :failed_authorization,
                                                    get_authorization_uri: 'https://example.com/authorize')
    end

    it 'must show storage information box with login button' do
      expect(page.find_test_selector('op-storage--information')).to have_button(count: 1)
    end
  end

  context 'if an error occurred while authorizing to Nextcloud' do
    before do
      allow(connection_manager).to receive(:authorization_state).and_return(:error)
    end

    it 'must show storage information box' do
      expect(page).to have_test_selector('op-storage--information', count: 1)
    end
  end
end
