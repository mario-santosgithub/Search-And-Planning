include "cumulative.mzn";

% ----------------------------------------------------------
%                      input variables
% ----------------------------------------------------------
bool : sameVehicleBackward;
int : maxWaitTime;

int : numberPlaces;
array[1..numberPlaces] of int : places;

int : numberVehicles;
array[1..numberVehicles, 1..3] of int : vehicles;

int : categories;
int : intervals;


array[1..numberVehicles, 1..categories] of int : canTake;

array[1..numberVehicles, 1..2*intervals] of int : availability;

int : numberPatients;

% value: list with: [category, load, startposition, endposition, startminut, destination, endminute, rdvTime, rdvDuration, srvDuration]
array[1..numberPatients, 1..9] of int : patients;
array[1..2*numberPatients] of int : loads;

% distance, in minutes, from position i to j, i = position index
array[1..numberPlaces, 1..numberPlaces] of int : distMatrix;

int : numberActivities = 2*numberPatients;

% ----------------------------------------------------------
%                   decision variables
% ----------------------------------------------------------

array[1..numberActivities] of var -1..1440 : start;
array[1..numberActivities] of var -1..1440 : end;
array[1..numberActivities] of var 0..1440 : duration;
array[1..numberActivities] of var 0..numberVehicles : assign;


% ----------------------------------------------------------
%                      constaints
% ----------------------------------------------------------

constraint forall(vehicle in 1..numberVehicles) (cumulative(start,duration,loads,vehicles[vehicle,3]));


constraint forall(patient in 1..numberPatients) (

                  if patients[patient,3] = -1 then
                    start[patient] = -1
                  endif /\

                  if patients[patient,4] = -1 then
                    end[patient] = -1 /\
                    start[patient+numberPatients] = -1
                  endif /\

                  if patients[patient,5] = -1 then
                    end[patient+numberPatients] = -1
                  endif
                  );



% Availability Constraint (FOR 1 INTERVAL)
constraint forall(patient in 1..numberPatients) (
                  if patients[patient,3] != -1 then
                    start[patient] >= availability[assign[patient], 1] +
                    distMatrix[vehicles[assign[patient], 1]+1, patients[patient, 3]+1]
                  endif /\

                  if patients[patient,4] != -1 then
                    end[patient] <= availability[assign[patient], 2] -
                    distMatrix[patients[patient, 4]+1, vehicles[assign[patient], 2]+1]
                  endif /\

                  if patients[patient,4] != -1 then
                    start[patient+numberPatients] >= availability[assign[patient+numberPatients], 1] +
                    distMatrix[vehicles[assign[patient+numberPatients], 1]+1, patients[patient, 4]+1]
                  endif /\

                  if patients[patient,5] != -1 then
                    end[patient+numberPatients] <= availability[assign[patient+numberPatients], 2] -
                    distMatrix[patients[patient, 5]+1, vehicles[assign[patient+numberPatients], 2]+1]
                  endif
                  );



constraint forall(patient in 1..numberPatients, vehicle in 1..numberVehicles, c in 1..categories) (
                    if patients[patient,1] != canTake[vehicle,1] /\ patients[patient,1] != canTake[vehicle,2] /\
                    patients[patient,1] != canTake[vehicle,3] then
                      assign[patient] != vehicle
                    endif
                  );


% max wait time constraint
constraint forall(patient in 1..numberPatients) (
                  % forward activities
                  if patients[patient, 3] != -1 then
                    start[patient] >= patients[patient, 6] - maxWaitTime /\
                    start[patient] <= patients[patient, 6]
                  endif /\

                  if patients[patient, 4] != -1 then
                    end[patient] >= patients[patient, 6] - maxWaitTime  /\
                    end[patient] <= patients[patient, 6]
                  endif /\

                  if patients[patient, 3] != -1  /\ patients[patient, 4] != -1 then
                    duration[patient] = end[patient] - start[patient]
                  endif /\

                  % backward
                  if patients[patient, 4] != -1 then
                    start[patient+numberPatients] >= patients[patient,6]+patients[patient, 7] /\
                    start[patient+numberPatients] <= patients[patient,6]+patients[patient, 7] + maxWaitTime
                  endif /\

                  if patients[patient, 5] != -1 then
                    end[patient+numberPatients] >= patients[patient,6]+patients[patient, 7] /\
                    end[patient+numberPatients] <= patients[patient,6]+patients[patient, 7] + maxWaitTime

                  endif /\

                  if patients[patient, 4] != -1  /\ patients[patient, 5] != -1 then
                    duration[patient+numberPatients] = end[patient+numberPatients] - start[patient+numberPatients]
                  endif

                  % FALTA CONSIDERAR CATEGORIAS

                  );

constraint forall(patient in 1..numberPatients) (
                  if patients[patient,3] != -1 /\ patients[patient,4] != -1 then
                    duration[patient] >= distMatrix[patients[patient, 3]+1,patients[patient,4]+1] + patients[patient,8]
                  endif /\

                  if patients[patient,4] != -1 /\ patients[patient,5] != -1 then
                    duration[patient+numberPatients] >= distMatrix[patients[patient,4]+1,patients[patient,5]+1] + patients[patient,8]
                  endif
                  );



constraint forall(i in 1..numberActivities, j in 1..numberActivities) (

           if i != j /\ i<=numberPatients /\ j<=numberPatients then

            if patients[i,3] != -1 /\ patients[j,3] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-start[i] >= distMatrix[patients[i,3]+1,patients[j,3]+1]+patients[i,8]  \/
              start[i]-start[j] >= distMatrix[patients[j,3]+1,patients[i,3]+1]+patients[j,8]))
            endif /\

            if patients[i,4] != -1 /\ patients[j,3] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-end[i] >= distMatrix[patients[i,4]+1,patients[j,3]+1] \/
              end[i]-start[j] >= distMatrix[patients[j,3]+1,patients[i,4]+1]+patients[i,8]+patients[j,8]))
            endif /\

            if patients[i,3] != -1 /\ patients[j,4] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-start[i] >= distMatrix[patients[i,3]+1,patients[j,4]+1]+patients[i,8]+patients[j,8] \/
              start[i]-end[j] >= distMatrix[patients[j,4]+1,patients[i,3]+1]))
            endif /\

            if patients[i,4] != -1 /\ patients[j,4] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-end[i] >= distMatrix[patients[i,4]+1,patients[j,4]+1]+patients[j,8] \/
              end[i]-end[j] >= distMatrix[patients[j,4]+1,patients[i,4]+1]+patients[i,8]))
            endif

           endif /\

           if i != j /\ i>numberPatients /\ j<=numberPatients then

            if patients[i-numberPatients,4] != -1 /\ patients[j,3] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-start[i] >= distMatrix[patients[i-numberPatients,4]+1,patients[j,3]+1]+patients[i-numberPatients,8]  \/
              start[i]-start[j] >= distMatrix[patients[j,3]+1,patients[i-numberPatients,4]+1]+patients[j,8]))
            endif /\

            if patients[i-numberPatients,5] != -1 /\ patients[j,3] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-end[i] >= distMatrix[patients[i-numberPatients,5]+1,patients[j,3]+1] \/
              end[i]-start[j] >= distMatrix[patients[j,3]+1,patients[i-numberPatients,5]+1]+patients[i-numberPatients,8]+patients[j,8]))
            endif /\

            if patients[i-numberPatients,4] != -1 /\ patients[j,4] != -1 then
            ((assign[i] = assign[j]) ->
            (end[j]-start[i] >= distMatrix[patients[i-numberPatients,4]+1,patients[j,4]+1]+patients[i-numberPatients,8]+patients[j,8] \/
            start[i]-end[j] >= distMatrix[patients[j,4]+1,patients[i-numberPatients,4]+1]))
            endif /\

            if patients[i-numberPatients,5] != -1 /\ patients[j,4] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-end[i] >= distMatrix[patients[i-numberPatients,5]+1,patients[j,4]+1]+patients[j,8] \/
              end[i]-end[j] >= distMatrix[patients[j,4]+1,patients[i-numberPatients,5]+1]+patients[i-numberPatients,8]))
            endif

           endif /\

           if i != j /\ i<=numberPatients /\ j>numberPatients then

            if patients[i,3] != -1 /\ patients[j-numberPatients,4] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-start[i] >= distMatrix[patients[i,3]+1,patients[j-numberPatients,4]+1]+patients[i,8]  \/
              start[i]-start[j] >= distMatrix[patients[j-numberPatients,4]+1,patients[i,3]+1]+patients[j-numberPatients,8]))
            endif /\

            if patients[i,4] != -1 /\ patients[j-numberPatients,4] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-end[i] >= distMatrix[patients[i,4]+1,patients[j-numberPatients,4]+1] \/
              end[i]-start[j] >= distMatrix[patients[j-numberPatients,4]+1,patients[i,4]+1]+patients[i,8]+patients[j-numberPatients,8]))
            endif /\

            if patients[i,3] != -1 /\ patients[j-numberPatients,5] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-start[i] >= distMatrix[patients[i,3]+1,patients[j-numberPatients,5]+1]+patients[i,8]+patients[j-numberPatients,8] \/
              start[i]-end[j] >= distMatrix[patients[j-numberPatients,5]+1,patients[i,3]+1]))
            endif /\

            if patients[i,4] != -1 /\ patients[j-numberPatients,5] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-end[i] >= distMatrix[patients[i,4]+1,patients[j-numberPatients,5]+1]+patients[j-numberPatients,8] \/
              end[i]-end[j] >= distMatrix[patients[j-numberPatients,5]+1,patients[i,4]+1]+patients[i,8]))
            endif

           endif /\

           if i != j /\ i>numberPatients /\ j>numberPatients then

            if patients[i-numberPatients,4] != -1 /\ patients[j-numberPatients,4] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-start[i] >= distMatrix[patients[i-numberPatients,4]+1,patients[j-numberPatients,4]+1]+patients[i-numberPatients,8]  \/
              start[i]-start[j] >= distMatrix[patients[j-numberPatients,4]+1,patients[i-numberPatients,4]+1]+patients[j-numberPatients,8]))
            endif /\

            if patients[i-numberPatients,5] != -1 /\ patients[j-numberPatients,4] != -1 then
              ((assign[i] = assign[j]) ->
              (start[j]-end[i] >= distMatrix[patients[i-numberPatients,5]+1,patients[j-numberPatients,4]+1] \/
              end[i]-start[j] >= distMatrix[patients[j-numberPatients,4]+1,patients[i-numberPatients,5]+1]+patients[i-numberPatients,8]+patients[j-numberPatients,8]))
            endif /\

            if patients[i-numberPatients,4] != -1 /\ patients[j-numberPatients,5] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-start[i] >= distMatrix[patients[i-numberPatients,4]+1,patients[j-numberPatients,5]+1]+patients[i-numberPatients,8]+patients[j-numberPatients,8] \/
              start[i]-end[j] >= distMatrix[patients[j-numberPatients,5]+1,patients[i-numberPatients,4]+1]))
            endif /\

            if patients[i-numberPatients,5] != -1 /\ patients[j-numberPatients,5] != -1 then
              ((assign[i] = assign[j]) ->
              (end[j]-end[i] >= distMatrix[patients[i-numberPatients,5]+1,patients[j-numberPatients,5]+1]+patients[j-numberPatients,8] \/
              end[i]-end[j] >= distMatrix[patients[j-numberPatients,5]+1,patients[i-numberPatients,5]+1]+patients[i-numberPatients,8]))
            endif

           endif
           );


% ----------------------------------------------------------
%                  objective function
% ----------------------------------------------------------

% Solve the CSP
solve minimize sum(activity in 1..numberActivities)(end[activity]); % Or use any appropriate solver


