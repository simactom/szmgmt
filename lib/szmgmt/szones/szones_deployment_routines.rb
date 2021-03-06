module SZMGMT
  module SZONES
    class SZONESDeploymentRoutines
      def self.decompose_vm_spec(vm_spec)
        parser = SZONESVMSpecParser.new(vm_spec)
        zonecfg   = parser.vm_spec_configuration
        manifest  = parser.vm_spec_manifest
        profile   = parser.vm_spec_profile
        [zonecfg, manifest, profile]
      end
      # Routine for deploying zone from configuration files. Frist file
      # is zone command file that can be exported from zonecfg command.
      # This file is the only one mandatory. Then you can specify manifest
      # and profile file that will be used with zone installation. If you
      # specify boot option the zone will boot after successful installation.
      # Steps:
      #   1) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   2) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   3) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_zone_from_files(zone_name, path_to_zonecfg, opts = {})
        ##########
        # OPTIONS
        boot                = opts[:boot] || false
        path_to_manifest    = opts[:path_to_manifest]
        path_to_profile     = opts[:path_to_profile]
        force               = opts[:force] || false
        logger              = opts[:logger] || SZMGMT.logger
        ##########
        # PREPARATION
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on localhost has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: FILES")
        begin
          SZONESBasicRoutines.remove_zone(zone_name) if force
          SZONESDeploymentSubroutines.deploy_zone_from_files(zone_name,
                                                             path_to_zonecfg,
                                                             {
                                                                 :id => id,
                                                                 :path_to_profile => path_to_profile,
                                                                 :path_to_manifest => path_to_manifest,
                                                                 :cleaner => cleaner,
                                                                 :logger => logger
                                                             })
        rescue Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          false
        else
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} succeeded.")
          if boot
            logger.info("DEPLOY (#{id}) - Booting up zone #{zone_name}")
            SZONESBasicZoneCommands.boot_zone(zone_name).exec
            logger.info("DEPLOY (#{id}) - Zone #{zone_name} booted.")
          end
          true
        ensure
          cleaner.cleanup_temporary!
        end
      end
      # Routine for deploying TEMPLATE from configuration files. Frist file
      # is zone command file that can be exported from zonecfg command.
      # This file is the only one mandatory. Then you can specify manifest
      # and profile file that will be used with zone installation. If you
      # specify boot option the zone will boot after successful installation.
      # Only diference from previous routine is the name of zone.
      # Steps:
      #   1) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   2) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   3) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_template_from_files(template_name, path_to_zonecfg, opts = {})
        full_template_name = "template_#{template_name}"
        deploy_zone_from_files(full_template_name, path_to_zonecfg, opts)
      end
      # Routine for deploying zone from vm_spec. This object is composition
      # of all needed configuration files as zonecfg, manifest and profile. So
      # firstly we need to decompose the vm_spec to specified files. If you
      # specify boot option the zone will boot after successful installation.
      # Only diference from previous routine is the name of zone.
      # Steps:
      #   1) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   2) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   3) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_zone_from_vm_spec(zone_name, vm_spec, opts = {})
        ##########
        # OPTIONS
        boot                = opts[:boot] || false
        tmp_dir             = opts[:tmp_dir] || '/var/tmp/'
        force               = opts[:force] || false
        logger              = opts[:logger] || SZMGMT.logger
        ##########
        # PREPARATION
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        random_id           = SZONESUtils.random_id          # Used for storing files during this transaction
        base_name           = "#{zone_name}_#{random_id}"    # Used for storing files during this transaction
        # Prepare file from vm_spec. It means parse vm_spec and
        # export it's parts to temporary files to target machine
        zonecfg, manifest, profile = decompose_vm_spec(vm_spec)
        # Export zonecfg to file
        path_to_zonecfg = File.join(tmp_dir, "#{base_name}.zonecfg")
        zonecfg.export_configuration_to_file(path_to_zonecfg)
        cleaner.add_tmp_file(path_to_zonecfg)
        # Export manifest to file if it was in VM_SPEC
        if manifest
          path_to_manifest = File.join(tmp_dir, "#{base_name}.manifest.xml")
          manifest.export_manifest_to_file(path_to_manifest)
          cleaner.add_tmp_file(path_to_manifest)
        end
        # Export profile to file if it was in VM_SPEC
        if profile
          path_to_profile = File.join(tmp_dir, "#{base_name}.profile.xml")
          profile.export_profile_to_file(path_to_profile)
          cleaner.add_tmp_file(path_to_profile)
        end
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on localhost has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: VM_SPEC")
        logger.info("DEPLOY (#{id}) -   vm_spec: #{vm_spec['name']}")
        begin
          SZONESBasicRoutines.remove_zone(zone_name) if force
          SZONESDeploymentSubroutines.deploy_zone_from_files(zone_name,
                                                             path_to_zonecfg,
                                                             {
                                                                 :id => id,
                                                                 :path_to_profile => path_to_profile,
                                                                 :path_to_manifest => path_to_manifest,
                                                                 :cleaner => cleaner
                                                             })
        rescue  Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} succeeded.")
          if boot
            logger.info("DEPLOY (#{id}) - Booting up zone #{zone_name}...")
            SZONESBasicZoneCommands.boot_zone(zone_name).exec
            logger.info("DEPLOY (#{id}) - Zone #{zone_name} booted.")
          end
          status = true
        ensure
          cleaner.cleanup_temporary!
        end
        status
      end
      # Routine for deploying TEMPLATE from vm_spec. This object is composition
      # of all needed configuration files as zonecfg, manifest and profile. So
      # firstly we need to decompose the vm_spec to specified files. If you
      # specify boot option the zone will boot after successful installation.
      # Only diference from previous routine is the name of zone.
      # Steps:
      #   1) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   2) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   3) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_template_from_vm_spec(template_name, vm_spec, opts = {})
        full_template_name = "template_#{template_name}"
        deploy_zone_from_vm_spec(full_template_name, vm_spec, opts)
      end
      # Routine for deploying zone from files on remote server. Frist file
      # is zone command file that can be exported from zonecfg command.
      # This file is the only one mandatory. Then you can specify manifest
      # and profile file that will be used with zone installation. If you
      # specify boot option the zone will boot after successful installation.
      #
      # Steps:
      #   1) copy files to remote server
      #   REMOTE HOST
      #   2) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   3) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   4) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_rzone_from_files(zone_name, dest_host_spec, path_to_zonecfg, opts = {})
        ##########
        # OPTIONS
        copy                = opts[:copy] || true
        boot                = opts[:boot] || false
        path_to_manifest    = opts[:path_to_manifest]
        path_to_profile     = opts[:path_to_profile]
        force               = opts[:force] || force
        logger              = opts[:logger] || SZMGMT.logger
        ##########
        # PREPARATION
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id
        random_id           = SZONESUtils.random_id
        tmp_dir             = opts[:tmp_dir] || '/var/tmp/'
        routine_options     = {
            :id => id,
            :cleaner => cleaner
        }
        dest_zonecfg        = File.join(tmp_dir, "#{random_id}_#{path_to_zonecfg.split('/').last}")
        files_to_copy       = [path_to_zonecfg]
        dest_files          = [dest_zonecfg]
        if path_to_manifest
          dest_manifest       = File.join(tmp_dir, "#{random_id}_#{path_to_manifest.split('/').last}")
          files_to_copy << path_to_manifest
          dest_files << dest_manifest
          routine_options[:path_to_manifest] = dest_manifest
        end
        if path_to_profile
          dest_profile        = File.join(tmp_dir, "#{random_id}_#{path_to_profile.split('/').last}")
          files_to_copy << path_to_profile
          dest_files << path_to_profile
          routine_options[:path_to_profile] = dest_profile
        end
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on host #{dest_host_spec[:host_name]} has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: FILES")
        begin
          #
          # EXECUTED ON LOCALHOST
          #
          # Copy files on remote server
          if copy
            logger.info("DEPLOY (#{id}) -      Copying files #{files_to_copy.join(', ')} to directory #{dest_host_spec[:host_name]}:#{tmp_dir}...")
            files_to_copy.each_with_index do |file, index|
              SZONESBasicCommands.copy_files_on_remote_host(file, dest_host_spec, dest_files[index]).exec
            end
            logger.info("DEPLOY (#{id}) -      Copying finished.")
            # Add files to cleaner to be able to delete it after transaction
            # is finished
            files_to_copy.each do |file|
              cleaner.add_tmp_file(file, dest_host_spec)
            end
          end
          #
          # EXECUTED ON DESTINATION HOST
          #
          logger.info("DEPLOY (#{id}) -      Connecting to remote host #{dest_host_spec[:host_name]}...")
          Net::SSH.start(dest_host_spec[:host_name], dest_host_spec[:user], dest_host_spec.to_h) do |ssh|
            SZONESBasicRoutines.remove_zone(zone_name, ssh) if force
            SZONESDeploymentSubroutines.deploy_zone_from_files(zone_name, dest_zonecfg, routine_options, ssh, dest_host_spec)
          end
          logger.info("DEPLOY (#{id}) -      Closing connection to remote host #{dest_host_spec[:host_name]}...")
        rescue  Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          if boot
            logger.info("DEPLOY (#{id}) -      Booting up zone #{zone_name}")
            SZONESBasicZoneCommands.boot_zone(zone_name).exec
            logger.info("DEPLOY (#{id}) -      Zone #{zone_name} booted.")
          end
          SZMGMT.logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} succeeded.")
          status = true
        ensure
          cleaner.cleanup_temporary!
        end
        status
      end
      # Routine for deploying TEMPLATE from files on remote server. This object is composition
      # of all needed configuration files as zonecfg, manifest and profile. So
      # firstly we need to decompose the vm_spec to specified files. If you
      # specify boot option the zone will boot after successful installation.
      # Only diference from previous routine is the name of zone.
      #
      # Steps:
      #  ?0) copy files to remote server
      #   REMOTE HOST
      #   1) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   2) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   3) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_rtemplate_from_files(template_name, path_to_zonecfg, opts = {})
        full_template_name = "template_#{template_name}"
        deploy_rzone_from_files(full_template_name, path_to_zonecfg, opts)
      end
      # Routine for deploying zone from VM_SPEC on remote server. This object is composition
      # of all needed configuration files as zonecfg, manifest and profile. So
      # firstly we need to decompose the vm_spec to specified files. If you
      # specify boot option the zone will boot after successful installation.
      #
      # Steps:
      #   1) copy files to remote server
      #   REMOTE HOST
      #   2) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   3) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   4) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_rzone_from_vm_spec(zone_name, dest_host_spec, vm_spec, opts = {})
        ##########
        # OPTIONS
        copy                = opts[:copy] || true
        boot                = opts[:boot] || false
        tmp_dir             = opts[:tmp_dir] || '/var/tmp/'
        force               = opts[:force] || false
        logger              = opts[:logger] || SZMGMT.logger
        ##########
        # PREPARATION
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        random_id           = SZONESUtils.random_id          # Used for storing files during this transaction
        base_name           = "#{zone_name}_#{random_id}"    # Used for storing files during this transaction
        files_to_copy       = []
        # Prepare file from vm_spec. It means parse vm_spec and
        # export it's parts to temporary files to target machine
        zonecfg, manifest, profile = decompose_vm_spec(vm_spec)
        # Export zonecfg to file
        path_to_zonecfg = File.join(tmp_dir, "#{base_name}.zonecfg")
        zonecfg.export_configuration_to_file(path_to_zonecfg)
        cleaner.add_tmp_file(path_to_zonecfg)
        files_to_copy << path_to_zonecfg
        # Export manifest to file if it was in VM_SPEC
        if manifest
          path_to_manifest = File.join(tmp_dir, "#{base_name}.manifest.xml")
          manifest.export_manifest_to_file(path_to_manifest)
          cleaner.add_tmp_file(path_to_manifest)
          files_to_copy << path_to_manifest
        end
        # Export profile to file if it was in VM_SPEC
        if profile
          path_to_profile = File.join(tmp_dir, "#{base_name}.profile.xml")
          profile.export_profile_to_file(path_to_profile)
          cleaner.add_tmp_file(path_to_profile)
          files_to_copy << path_to_profile
        end
        ###########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on host #{dest_host_spec[:host_name]} has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: VM_SPEC")
        logger.info("DEPLOY (#{id}) -   vm_spec: #{vm_spec['name']}")
        begin
          #
          # EXECUTED ON LOCALHOST
          #
          # Copy files on remote server

          if copy
            logger.info("DEPLOY (#{id}) -      Copying files #{files_to_copy.join(', ')} to directory #{dest_host_spec[:host_name]}:#{tmp_dir}...")
            SZONESBasicCommands.copy_files_on_remote_host(files_to_copy, dest_host_spec, tmp_dir).exec
            logger.info("DEPLOY (#{id}) -      Copying finished.")
            # Add files to cleaner to be able to delete it after transaction
            # is finished
            files_to_copy.each do |file|
              cleaner.add_tmp_file(file, dest_host_spec)
            end
          end
          #
          # EXECUTED ON DESTINATION HOST
          #
          logger.info("DEPLOY (#{id}) -      Connecting to remote host #{dest_host_spec[:host_name]}...")
          Net::SSH.start(dest_host_spec[:host_name], dest_host_spec[:user], dest_host_spec.to_h) do |ssh|
            SZONESBasicRoutines.remove_zone(zone_name, ssh) if force
            SZONESDeploymentSubroutines.deploy_zone_from_files(zone_name,
                                                               path_to_zonecfg,
                                                               {
                                                                   :id => id,
                                                                   :path_to_manifest => path_to_manifest,
                                                                   :path_to_profile => path_to_profile,
                                                                   :cleaner => cleaner
                                                               },
                                                               ssh,
                                                               dest_host_spec)
          end
          logger.info("DEPLOY (#{id}) -      Closing connection to remote host #{dest_host_spec[:host_name]}...")
        rescue  Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          if boot
            logger.info("DEPLOY (#{id}) -      Booting up zone #{zone_name}")
            SZONESBasicZoneCommands.boot_zone(zone_name).exec
            logger.info("DEPLOY (#{id}) -      Zone #{zone_name} booted.")
          end
          logger.info("DEPLOY (#{id}) - Deployment of template #{zone_name} succeeded.")
          status = true
        ensure
          cleaner.cleanup_temporary!
        end
        status
      end
      # Routine for deploying TEMPLATE from VM_SPEC on remote server. This object is composition
      # of all needed configuration files as zonecfg, manifest and profile. So
      # firstly we need to decompose the vm_spec to specified files. If you
      # specify boot option the zone will boot after successful installation.
      # Only diference from previous routine is the name of zone.
      #
      # Steps:
      #   1) copy files to remote server
      #   REMOTE HOST
      #   2) zonecfg -z %{zonename} -f %{path_to_zonecfg}   - Create zone configuration
      #   3) zoneadm -z %{zonename} install -m %{manifest}  - Install the zone using manifest and
      #                                     -c %{profile}     profile files
      #   if boot
      #   4) zoneadm -z %{zonename} boot                    - Boot the zone if boot opt specified
      def self.deploy_rtemplate_from_vm_spec(template_name, vm_spec, opts = {})
        full_template_name = "template_#{template_name}"
        deploy_rtemplate_from_vm_spec(full_template_name, vm_spec, opts)
      end
      #
      #
      #
      #
      #
      def self.deploy_zone_from_zone(zone_name, source_zone_name, opts = {})
        ##########
        # OPTIONS
        force               = opts[:force] || false
        boot                = opts[:boot] || false
        halt                = opts[:halt] || false
        logger              = opts[:logger] || SZMGMT.logger
        if opts[:zonepath]
          zonepath = File.join( opts[:zonepath], zone_name )
        end
        ##########
        # PREPARATION
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} from zone #{source_zone_name} has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: clone")
        begin
          if halt
            logger.info("DEPLOY (#{id}) -      Trying to halt the source zone #{source_zone_name}...")
            halt = SZONESBasicZoneCommands.halt_zone(source_zone_name).exec
            booted = true unless halt.stderr =~ /already halted/
            logger.info("DEPLOY (#{id}) -      Source zone #{source_zone_name} halted.")
          end
          SZONESBasicRoutines.remove_zone(zone_name) if force
          SZONESDeploymentSubroutines.deploy_zone_from_local_zone(zone_name,
                                                                  source_zone_name,
                                                                  {
                                                                      :id => id,
                                                                      :zonepath => zonepath,
                                                                      :cleaner => cleaner
                                                                  })
        rescue Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          SZONESDeploymentSubroutines.boot_zone(zone_name, {:id => id}) if boot
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} succeeded.")
          status = true
        ensure
          SZONESDeploymentSubroutines.boot_zone(source_zone_name, {:id => id}) if halt && booted
          cleaner.cleanup_temporary!
        end
        status
      end
      #
      #
      #
      #
      #
      def self.rdeploy_zone_from_zone(zone_name, dest_host_spec, source_zone_name, opts = {})
        ##########
        # OPTIONS
        force               = opts[:force] || false
        boot                = opts[:boot] || false
        halt                = opts[:halt] || false
        logger              = opts[:logger] || SZMGMT.logger
        if opts[:zonepath]
          zonepath = File.join( opts[:zonepath], zone_name )
        end
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} from zone #{source_zone_name} on host #{dest_host_spec[:host_name]} has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: clone")
        begin
          logger.info("DEPLOY (#{id}) -      Connecting to host #{dest_host_spec[:host_name]}...")
          ssh = Net::SSH.start(dest_host_spec[:host_name], dest_host_spec[:user], dest_host_spec.to_h)
          if halt
            logger.info("DEPLOY (#{id}) -      Trying to halt the source zone #{source_zone_name}...")
            halt = SZONESBasicZoneCommands.halt_zone(source_zone_name).exec_ssh(ssh)
            booted = true unless halt.stderr =~ /already halted/
            logger.info("DEPLOY (#{id}) -      Source zone #{source_zone_name} halted.")
          end
          SZONESBasicRoutines.remove_zone(zone_name, ssh) if force
          SZONESDeploymentSubroutines.deploy_zone_from_local_zone(zone_name,
                                                                  source_zone_name,
                                                                  {
                                                                      :id => id,
                                                                      :zonepath => zonepath,
                                                                      :cleaner => cleaner
                                                                  },
                                                                  ssh,
                                                                  dest_host_spec)
        rescue Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          SZONESDeploymentSubroutines.boot_zone(zone_name, {:id => id}, ssh) if boot
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} succeeded.")
          status = true
        ensure
          SZONESDeploymentSubroutines.boot_zone(source_zone_name, {:id => id}, ssh) if halt && booted
          cleaner.cleanup_temporary!
          ssh.close if ssh
        end
        status
      end
      #
      #
      #
      #
      #
      def self.deploy_zone_from_rzone(zone_name, source_host_spec, source_zone_name, opts = {})
        ##########
        # OPTIONS
        force               = opts[:force] || false
        boot                = opts[:boot] || false
        halt                = opts[:halt] || false
        logger              = opts[:logger] || SZMGMT.logger
        if opts[:zonepath]
          zonepath = File.join( opts[:zonepath], zone_name )
        end
        tmp_dir             = opts[:tmp_dir] || '/var/tmp'
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} from zone '#{source_zone_name}:#{source_host_spec[:host_name]}' has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: ZFS archive")
        begin
          logger.info("DEPLOY (#{id}) -      Connecting to host #{source_host_spec[:host_name]}...")
          ssh = Net::SSH.start(source_host_spec[:host_name], source_host_spec[:user], source_host_spec.to_h)
          if halt
            logger.info("DEPLOY (#{id}) -      Trying to halt the source zone #{source_zone_name}...")
            halt = SZONESBasicZoneCommands.halt_zone(source_zone_name).exec_ssh(ssh)
            booted = true unless halt.stderr =~ /already halted/
            logger.info("DEPLOY (#{id}) -      Source zone #{source_zone_name} halted.")
          end
          path_to_archive, path_to_zonecfg = SZONESDeploymentSubroutines.export_zone_to_zfs_archive(source_zone_name,
                                                                                                    {:id => id, :cleaner => cleaner}.merge(opts), ssh,
                                                                                                    source_host_spec )
          SZONESBasicCommands.copy_files_from_remote_host([path_to_archive, path_to_zonecfg], source_host_spec, tmp_dir).exec
          SZONESBasicRoutines.remove_zone(zone_name) if force
          SZONESDeploymentSubroutines.deploy_zone_from_zfs_archive(zone_name, path_to_archive, path_to_zonecfg,
                                                                   { :id => id, :cleaner => cleaner, :zonepath => zonepath}.merge(opts))

        rescue Exceptions::SZONESError
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          SZONESDeploymentSubroutines.boot_zone(zone_name, {:id => id}) if boot
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} succeeded.")
          status = true
        ensure
          SZONESDeploymentSubroutines.boot_zone(source_zone_name, {:id => id}, ssh) if halt && booted
          cleaner.cleanup_temporary!
          ssh.close if ssh
        end
        status
      end
      #
      #
      #
      #
      #
      def self.deploy_rzone_from_zone(zone_name, dest_host_spec, source_zone_name, opts = {})
        ##########
        # OPTIONS
        force               = opts[:force] || false
        boot                = opts[:boot] || false
        halt                = opts[:halt] || false
        logger              = opts[:logger] || SZMGMT.logger
        if opts[:zonepath]
          zonepath = File.join( opts[:zonepath], zone_name )
        end
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on #{dest_host_spec[:host_name]} from zone '#{source_zone_name}' has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: ZFS archive")
        begin
          if halt
            logger.info("DEPLOY (#{id}) -      Trying to halt the source zone #{}...")
            halt = SZONESBasicZoneCommands.halt_zone(source_zone_name).exec
            booted = true unless halt.stderr =~ /already halted/
            logger.info("DEPLOY (#{id}) -      Source zone #{source_zone_name} on localhost halted.")
          end
          path_to_archive, path_to_zonecfg = SZONESDeploymentSubroutines.export_zone_to_remote_zfs_archive(source_zone_name, dest_host_spec,
                                                                                                           {:id => id, :cleaner => cleaner}.merge(opts))
          logger.info("DEPLOY (#{id}) -      Connecting to host #{dest_host_spec[:host_name]}...")
          ssh = Net::SSH.start(dest_host_spec[:host_name], dest_host_spec[:user], dest_host_spec.to_h)
          SZONESBasicRoutines.remove_zone(zone_name, ssh) if force
          SZONESDeploymentSubroutines.deploy_zone_from_zfs_archive(zone_name, path_to_archive, path_to_zonecfg,
                                                                   { :id => id, :cleaner => cleaner, :zonepath => zonepath}.merge(opts),
                                                                   ssh, dest_host_spec)
        rescue Exceptions::SZONESError
          logger.error("DEPLOY (#{id}) - Deployment of zone #{zone_name} on #{dest_host_spec[:host_name]} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          SZONESDeploymentSubroutines.boot_zone(zone_name, {:id => id}, ssh) if boot
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} succeeded.")
          status = true
        ensure
          SZONESDeploymentSubroutines.boot_zone(source_zone_name, {:id => id}) if halt && booted
          cleaner.cleanup_temporary!
          ssh.close if ssh
        end
        status
      end
      #
      #
      #
      #
      #
      def self.deploy_rzone_from_rzone(zone_name, dest_host_spec, source_zone_name, source_host_spec, opts = {})
        ##########
        # OPTIONS
        force               = opts[:force] || false
        boot                = opts[:boot] || false
        halt                = opts[:halt] || false
        logger              = opts[:logger] || SZMGMT.logger
        if opts[:zonepath]
          zonepath = File.join( opts[:zonepath], zone_name )
        end
        cleaner             = SZONESCleanuper.new
        id                  = SZONESUtils.transaction_id     # Used for marking this transaction
        ##########
        # EXECUTION
        logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on #{dest_host_spec[:host_name]} from zone '#{source_zone_name}' has been initialize...")
        logger.info("DEPLOY (#{id}) -      type: ZFS archive")
        begin
          logger.info("DEPLOY (#{id}) -      Connecting to host #{source_host_spec[:host_name]}...")
          ssh_source = Net::SSH.start(source_host_spec[:host_name], source_host_spec[:user], source_host_spec.to_h)
          if halt
            logger.info("DEPLOY (#{id}) -      Trying to halt the source zone #{source_zone_name} on  host #{source_host_spec[:host_name]}...")
            halt = SZONESBasicZoneCommands.halt_zone(source_zone_name).exec_ssh(ssh_source)
            booted = true unless halt.stderr =~ /already halted/
            logger.info("DEPLOY (#{id}) -      Source zone #{source_zone_name} on host #{source_host_spec[:host_name]} halted.")
          end
          path_to_archive, path_to_zonecfg = SZONESDeploymentSubroutines.export_zone_to_remote_zfs_archive(source_zone_name, dest_host_spec,
                                                                                                           {:id => id, :cleaner => cleaner}.merge(opts),
                                                                                                           ssh_source, source_host_spec)
          logger.info("DEPLOY (#{id}) -      Connecting to host #{dest_host_spec[:host_name]}...")
          ssh_dest = Net::SSH.start(dest_host_spec[:host_name], dest_host_spec[:user], dest_host_spec.to_h)
          SZONESBasicRoutines.remove_zone(zone_name, ssh_dest) if force
          SZONESDeploymentSubroutines.deploy_zone_from_zfs_archive(zone_name, path_to_archive, path_to_zonecfg,
                                                                   { :id => id, :cleaner => cleaner, :zonepath => zonepath}.merge(opts),
                                                                   ssh_dest, dest_host_spec)
        rescue Exceptions::SZONESError
          logger.error("DEPLOY (#{id}) - Deployment of zone #{zone_name} on #{dest_host_spec[:host_name]} failed.")
          cleaner.cleanup_on_failure!
          status = false
        else
          SZONESDeploymentSubroutines.boot_zone(zone_name, {:id => id}, ssh_dest) if boot
          logger.info("DEPLOY (#{id}) - Deployment of zone #{zone_name} on #{dest_host_spec[:host_name]} succeeded.")
          status = true
        ensure
          SZONESDeploymentSubroutines.boot_zone(source_zone_name, {:id => id}, ssh_source) if halt && booted
          cleaner.cleanup_temporary!
          ssh_source.close if ssh_source
          ssh_dest.close if ssh_dest
        end
        status
      end
    end
  end
end
