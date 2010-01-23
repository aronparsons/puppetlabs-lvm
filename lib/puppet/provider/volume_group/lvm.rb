Puppet::Type.type(:volume_group).provide :lvm do

    desc "Manages LVM volume groups"

    commands :vgcreate => 'vgcreate',
             :vgremove => 'vgremove',
             :vgs      => 'vgs',
             :vgextend => 'vgextend',
             :vgreduce => 'vgreduce'

    confine    :kernel => :linux
    defaultfor :kernel => :linux

    def create
        vgcreate(@resource[:name], *@resource.should(:physical_volumes))
    end

    def destroy
        vgremove(@resource[:name])
    end

    def exists?
        vgs(@resource[:name])
    end

    def physical_volumes=(new_volumes = [])
        existing_volumes = physical_volumes
        extraneous = existing_volumes - new_volumes
        extraneous.each { |volume| extend_with(volume) }
        missing = new_volumes - existing_volumes
        missing.each { |volume| reduce_with(volume) }
    end

    def physical_volumes
        lines = pvs(@resource[:name], '-o', 'pv_name,vg_name', '--separator', ',')
        lines.inject([]) do |memo, line|
            pv, vg = line.split(',')
            if vg == @resource[:name]
                memo << vg
            else
                memo
            end
        end
    end

    private

    def reduce_with(volume)
        vgreduce(@resource[:name], volume)
    rescue Puppet::ExecutionFailure => detail
        raise Puppet::Error, "Could not remove physical volume #{volume} from volume group '#{@resource[:name]}'; this physical volume may be in use and may require a manual data migration (using pvmove) before it can be removed (#{detail.message})"
    end

    def extend_with(volume)
        vgextend(@resource[:name], volume)
    rescue Puppet::ExecutionFailure => detail
        raise Puppet::Error, "Could not extend volume group '#{@resource[:name]}' with physical volume #{volume} (#{detail.message})"
    end
end
