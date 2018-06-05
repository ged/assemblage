# -*- ruby -*-
# frozen_string_literal: true

Sequel.migration do
	up do
		create_table( :repositories ) do
			primary_key :id
			String :client_name, null: false
			String :type, null: false
			String :url, null: false
		end

		create_table( :clients ) do
			primary_key :id
			String :name, null: false
			String :type, null: false

			unique [:name, :type]
			constraint( :client_type, type: %w[repository worker] )
		end

		create_table( :assemblies ) do
			primary_key :id
			String :name, null: false
			foreign_key :repository_id, :repositories, null: false,
				on_delete: :cascade
		end

		create_table( :assembly_results ) do
			primary_key :id
			Time :created_at
			Time :finished_at
			foreign_key :assembly_id, :assemblies, null: false,
				on_delete: :cascade
			foreign_key :client_id, :clients, null: false,
				on_delete: :cascade
		end
	end

	down do
		drop_table( :assembly_results, cascade: true )
		drop_table( :assemblies, cascade: true )
		drop_table( :clients, cascade: true )
		drop_table( :repositories, cascade: true )
	end
end

