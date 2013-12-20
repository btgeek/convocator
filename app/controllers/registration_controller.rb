class RegistrationController < ApplicationController
    def index
        redirect_to current_user
    end

    def create
        @registrant = current_user.registrants.build
        @registrant.name = params[:name]
        @registrant.save

        redirect_to (Qualifier.count > 0 ? qualifiers_path(@registrant) : @registrant.user), :notice => 'Created registrant.'
    end

    def show
        @registrant = current_user.registrants.find(params[:id])
    end

    def destroy
        @registrant = current_user.registrants.find(params[:id])
        user = @registrant.user
        if @registrant.balance == 0 && @registrant.events.count == 0
            @registrant.destroy
            redirect_to user, :notice => 'Deleted registrant.'
        else
            redirect_to user, :alert => 'You cannot remove a registrant with an outstanding balance or current enrollments.'
        end
    end

    def charges
        @registrant = Registrant.find(params[:id])
        @charges = @registrant.charges.order('created_at DESC')
    end

    def qualifiers
        @registrant = Registrant.find(params[:id])
        @registrant.groups = []
        @registrant.save
        @qualifiers = Qualifier.all
    end

    def qualify
        @registrant = Registrant.find(params[:id])
        @qualifiers = Qualifier.all

        @qualifiers.each do |q|
            q.group.registrants << @registrant if q.qualify @registrant, params["qu#{q.id}"]
        end
        redirect_to @registrant.user
    end

    def charge
        @registrant = Registrant.find(params[:id])
        @charge = @registrant.charges.build
        @charge.charger_type = 'Organizer'
        @charge.charger_id = current_organizer.id
        @charge.amount = params[:amount]
        @charge.comment = params[:comment]
        @charge.description = params[:description]
        @charge.icon = params[:icon]
        if @charge.save
            redirect_to registrant_charges_path(@registrant), :notice => 'Charge posted.'
        else
            redirect_to registrant_charges_path(@registrant), :alert => 'Charge unsucessful.'
        end
    end

    def register
        @registrant = Registrant.find(params[:registrant_id])
        @event = Event.find(params[:event_id])

        if @event.allows? @registrant
            if @event.registrants.count < @event.limit || @event.limit == nil || @event.waitable
                r = Registration.create(:registrant_id => @registrant.id, :event_id => @event.id)

                if @event.limit != nil && @event.waitable && @event.registrants.count > @event.limit  
                    r.waiting = true
                    r.save
                end

                if @event.cost != 0 && !r.waiting
                    @charge = @registrant.charges.build()
                    @charge.charger = @event
                    @charge.amount = @event.cost
                    @charge.comment = "Registered for #{@event.name}"
                    @charge.description = ''
                    @charge.icon = @event.icon || 'ticket'
                    @charge.save
                end

                @event.register_rules @registrant

                if r.waiting
                    redirect_to @registrant.user, :notice => "#{@registrant.name} is on the waitlist for #{@event.name}!"
                else
                    redirect_to @registrant.user, :notice => "Registered #{@registrant.name} for #{@event.name}!"
                end

            else
                redirect_to event_path(@event), :alert => "#{@event.name} is full."
            end

        else
            redirect_to event_path(@event), :alert => "#{@registrant.name} is not allowed to register for that."
        end
    end

    def unregister
        @registrant = Registrant.find(params[:registrant_id])
        @event = Event.find(params[:event_id])

        if @event.registrants.include? @registrant
            r = Registration.where(:event_id => @event.id, :registrant_id => @registrant.id).first
            unless r.waiting
                if @event.cost != 0 || @event.cost != nil
                    @charge = @registrant.charges.build()
                    @charge.charger = @event
                    @charge.amount = -@event.cost
                    @charge.comment = "Canceled registration for #{@event.name}"
                    @charge.description = ''
                    @charge.icon = @event.icon || 'ticket'
                    @charge.save
                end
            end
            @event.unregister_rules @registrant

            r.delete

            if @event.registrations.where(:waiting => true).count > 0
                promote = @event.registrations.where(:waiting => true).order('created_at ASC').first
                promote.waiting = false
                promote.save
                if @event.cost != 0 && !r.waiting
                    @charge = promote.registrant.charges.build()
                    @charge.charger = @event
                    @charge.amount = @event.cost
                    @charge.comment = "Registered for #{@event.name}"
                    @charge.description = 'Promoted off waitlist.'
                    @charge.icon = @event.icon || 'ticket'
                    @charge.save
                end
            end

            redirect_to @registrant.user, :notice => "Unregistered #{@registrant.name} from #{@event.name}!"
        else
            redirect_to event_path(@event), :alert => "#{@registrant.name} is not registered for that event."
        end

    end

end