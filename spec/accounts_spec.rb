require 'spec_helper'

describe 'accounts' do
  context "with two clients pointed to different clouds", :mock_only do
    let!(:client_1) { create_hmac_client(url: 'http://client-1.example.com') }
    let!(:client_2) { create_hmac_client(url: 'http://client-2.example.com') }
      it "should not about each other's accounts" do
        owner_1   = client_1.users.create!(name: Faker::Name.name, email: Faker::Internet.email)
        account_1 = client_1.accounts.create!(owner: owner_1, name: Faker::Name.first_name)

        owner_2   = client_2.users.create!(name: Faker::Name.name, email: Faker::Internet.email)
        account_2 = client_2.accounts.create!(owner: owner_2, name: Faker::Name.first_name)

        expect(client_1.accounts.get(account_2.id)).to be_nil
        expect(client_2.accounts.get(account_1.id)).to be_nil
      end

  end

  context "with a hmac client" do
    let!(:hmac_client) { create_hmac_client }

    context "with a user" do
      let!(:user) { hmac_client.users.create!(name: Faker::Name.name, email: Faker::Internet.email) }
      let(:user_client) { create_client }

      it "should create an account" do
        name = Faker::Name.first_name

        account = hmac_client.accounts.create!(owner: user, name: name, signup_via: "deis")

        expect(account.name).to eq(name)
        expect(account.support_plan).to eq("standard")
        expect(account.signup_via).to eq("deis")

        users = account.users.all
        expect(users.size).to eq(1)
        expect(users.first).to eq(user)
      end

      it "should create an account by name_prefix" do
        account1 = hmac_client.accounts.create!(owner: user, name_prefix: "azure")
        account2 = hmac_client.accounts.create!(owner: user, name_prefix: "azure")

        expect(account1.name).to match(/azure/)
        expect(account2.name).to match(/azure/)
      end

      it "should be able to invite collaborators", :mock_only do
        account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name, type: "normal")
        collaborator  = hmac_client.users.create!(name: Faker::Name.name, email: Faker::Internet.email)

        collaborator.reload
        expect(collaborator.accounts.all).to be_empty
        account.reload
        expect(account.users.all.size).to eq 1
        expect(account.users.all.map(&:id)).to eq [user.id]
        expect(account.owners.all.size).to eq 1
        expect(account.owners.all.map(&:id)).to eq [user.id]

        invite = user_client.memberships.create!(account: account, role: "collaborator", user: collaborator)

        collaborator.reload
        expect(collaborator.accounts.all).to be_empty
        account.reload
        expect(account.users.all.size).to eq 1
        expect(account.users.all.map(&:id)).to eq [user.id]
        expect(account.owners.all.size).to eq 1
        expect(account.owners.all.map(&:id)).to eq [user.id]

        collaborator_client = create_client(user: collaborator)
        membership = collaborator_client.memberships.get(invite.id)
        membership.accept!

        collaborator.reload
        expect(collaborator.accounts.all.size).to eq 1
        expect(collaborator.accounts.first.id).to eq account.id
        account.reload
        expect(account.users.all.size).to eq 2
        expect(account.users.all.map(&:id).sort).to eq [user.id, collaborator.id].sort
        expect(account.owners.all.size).to eq 1
        expect(account.owners.all.map(&:id)).to eq [user.id]
      end

      it "should cancel an account" do
        account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)
        c = account.cancel!(:requested_by => user)
        expect(c.kind).to eq "self"
        account_refetched = hmac_client.accounts.get(account.id)
        expect(account_refetched.cancelled_at).not_to be_nil
        expect(account_refetched.cancellation).to eq c
      end

      it "should get an account" do
        account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)

        expect(hmac_client.accounts.get(account.id)).to eq(account)
      end

      it "should have a nil cancellation" do
        account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)
        expect(account.cancellation).to be_nil
      end

      it "should get all accounts for a user" do
        account         = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)
        another_user    = hmac_client.users.create!(name: Faker::Name.name, email: Faker::Internet.email)
        another_account = hmac_client.accounts.create!(owner: another_user, name: Faker::Name.first_name)

        expect(user.accounts.all).to match_array([account])
      end

      context "a second user" do
        let!(:user2) { hmac_client.users.create!(name: Faker::Name.name, email: Faker::Internet.email) }

        it "should not be associated with unrelated users" do
          name = Faker::Name.first_name

          account = hmac_client.accounts.create!(owner: user2, name: name)

          users = account.users.all

          expect(users.size).to eq(1)
          expect(users.first).to eq(user2)
        end
      end

      it "should search by legacy_id", mock_only: true do
        legacy_id = Cistern::Mock.random_numbers(6)

        account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)
        hmac_client.data[:accounts][account.id]["legacy_id"] = legacy_id

        expect(hmac_client.accounts.first(legacy_id: legacy_id)).to eq(account)
      end

      context "owners" do
        it "should contain the owner user" do
          account = hmac_client.accounts.create!(owner: user, name: Faker::Name.first_name)

          owner = account.owners.all.first
          expect(owner.id).to eq(user.id)
        end
      end
    end
  end
end