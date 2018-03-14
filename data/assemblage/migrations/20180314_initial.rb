# -*- ruby -*-
# frozen_string_literal: true

Sequel.migration do
	up do
		create_table( :assemblies ) do
			primary_key :id
		end

		create_table( :clients ) do
			primary_key :id
		end

		create_table( :repositories ) do
			primary_key :id
		end
	end

	down do
		drop_table( :assemblies, cascade: true )
		drop_table( :clients, cascade: true )
		drop_table( :repositories, cascade: true )
	end
end

