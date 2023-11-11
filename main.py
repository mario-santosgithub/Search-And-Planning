from minizinc import Instance, Model, Solver
import json
import sys

# stringTime: HHhMM or HHhMM:HHhMM
# int -> in minutes
def parseTime(time):
    # simple time

    if (type(time) == str and len(time) == 5):
        hoursStr = time[:2]
        minutesStr = time[3:]

        return int(hoursStr) * 60 + int(minutesStr)

    # interval
    elif(type(time) == str and len(time) == 11):
        hoursStr1 = time[:2]
        minutesStr1 = time[3:5]

        hoursStr2 = time[6:8]
        minutesStr2 = time[9:]

        return [int(hoursStr1) * 60 + int(minutesStr1), int(hoursStr2) * 60 + int(minutesStr2)]
    # we are reading an integer in minutes
    else:
        hours = int(time) // 60
        remaining_minutes = int(time) % 60

        if remaining_minutes >= 10:
            return f"{hours}h{remaining_minutes}"
        else:
            return f"{hours}h0{remaining_minutes}"

# vehicleId already with +1
def findFirst(start, assign, vehicleId):
    while True:
        minTime = min(start)
        index = start.index(minTime)
        print("v:",vehicleId)
        print("i:",index)
        if assign[index] == vehicleId:
            return index
        else:
            start[index] = 9999
            assign[index] = 9999
    pass



def main():
    inputFile = sys.argv[1]
    outputFile = sys.argv[2]

    #print(inputFile)
    #print(outputFile)

    # open the file and create a dictionary
    with open(inputFile, "r") as file:
        temp = json.load(file)

    # --------------------------------
    #           Format Input
    # --------------------------------
    sameVehicleBackward = temp["sameVehicleBackward"]
    maxWaitTime = parseTime(temp["maxWaitTime"])

    places = []
    for place in temp["places"]:
        places.append(place.get("category"))

    # variable vehicles matrix with:
    # 0: id
    # 1: start
    # 2: end
    # 3: capacity
    vehicles = []
    canTake = []
    availability = []


    categories = 0
    intervals = 0
    vehiclesId = temp["vehicles"][0]["id"]
    for vehicle in temp["vehicles"]:
        if (max(vehicle["canTake"]) > categories):
            categories = len(vehicle["canTake"])

        if (len(vehicle["availability"]) > intervals):
            intervals = len(vehicle["availability"])

        vehicles.append([vehicle["start"], vehicle["end"], vehicle["capacity"]])
        canTake.append(vehicle["canTake"])

        size = len(vehicle["availability"])
        lst = []
        for i in range(size):
            lst += parseTime(vehicle["availability"][i])
        availability.append(lst)

    for i in range(len(availability)):
        while (2*intervals-len(availability[i]) != 0):
            availability[i] += [-1, -1]
    # [0,1,2]
    categories = 3
    for l in canTake:
        while (len(l) != 3):
            l.append(-1)


    patients = []
    loads = []
    firstPatientId = temp["patients"][0]["id"]
    for patient in temp["patients"]:
        patients.append([patient["category"], patient["load"],
                         patient["start"], patient["destination"], patient["end"],
                         parseTime(patient["rdvTime"]), parseTime(patient["rdvDuration"]),
                         parseTime(patient["srvDuration"]), 0])
        loads.append(patient["load"])
    resLoad = loads + loads


    patientsId = temp["patients"][0]["id"]

    distMatrix = temp["distMatrix"]


    print(vehiclesId)
    print(patientsId)
    #print(distMatrix)
    # --------------------------------
    #   Send Varialbes to Minizinc
    # --------------------------------
    print("matrix:", distMatrix)
    print("patients", patients)
    print("vehicles",vehicles)
    print("availability", availability)
    print("c:", canTake)
    #print("canTake", canTake)
    ptp = Model("./proj.mzn")
    gecode = Solver.lookup("gecode")
    instance = Instance(gecode, ptp)

    # assign instances
    instance["sameVehicleBackward"] = sameVehicleBackward
    instance["maxWaitTime"] = maxWaitTime
    instance["numberPlaces"] = len(places)
    instance["places"] = places
    instance["numberVehicles"] = len(vehicles)
    instance["categories"] = categories
    instance["intervals"] = intervals
    instance["vehicles"] = vehicles
    instance["canTake"] = canTake
    instance["availability"] = availability
    instance["numberPatients"] = len(patients)
    instance["patients"] = patients
    instance["loads"] = resLoad
    instance["distMatrix"] = distMatrix

    # ----------------------------------------------
    #   Solve and Receive Varialbes from Minizinc
    # ----------------------------------------------
    result = instance.solve()
    # Output the array q
    print(result)
    start = result["start"]
    end = result["end"]
    duration = result["duration"]
    assign = result["assign"]
    print("s:",start)
    print("e:",end)
    print("d:",duration)
    print("a:",assign)

    vehiclesOut = []
    for vehicleIndex in range(len(vehicles)):

        trips = []
        s = True
        load = []
        lastTripTime = 0
        lastTripPlace = 0
        secondIndex = 0

        # create new lists with only the assigned patients
        print("----------------")
        cpyStart = []
        cpyEnd = []
        print(start)
        print(end)
        for patientId in range(2*len(patients)):
            if assign[patientId] == vehicleIndex+1:
                if start[patientId] == -1 or end[patientId] == -1:
                    cpyStart.append(9999)
                    cpyEnd.append(9999)

                else:
                    cpyStart.append(start[patientId])
                    cpyEnd.append(end[patientId])

        print(cpyStart)
        print(cpyEnd)
        # pick the index for the minimum value of time


        # Add the first trip of the vehicle
        # check if the vehicle has trips
        if cpyStart == [] and cpyEnd == []:
            vehicleInfo = {
                "id": vehiclesId+vehicleIndex,
                "trips": trips
            }
            vehiclesOut.append(vehicleInfo)
            break
        startIndex = cpyStart.index(min(cpyStart))

        if startIndex <= len(patients)-1:
            tripInfo = {
                "origin": vehicles[vehicleIndex][0],
                "destination": patients[startIndex][2],
                "arrival": parseTime(start[startIndex]),
                "patients": load.copy()
            }
            load.append(patientsId + startIndex)
        else:
            tripInfo = {
                "origin": vehicles[vehicleIndex][0],
                "destination": patients[startIndex-len(patients)][3],
                "arrival": parseTime(start[startIndex]),
                "patients": load.copy()
            }
            load.append(patientsId + startIndex - len(patients))

        trips.append(tripInfo)
        cpyStart[startIndex] = 9999


        startIndex = cpyStart.index(min(cpyStart))
        endIndex = cpyEnd.index(min(cpyEnd))

        while cpyStart[startIndex] != 9999 or cpyEnd[endIndex] != 9999:
            # They are never the same, only > or <
            # the minimum is on start list
            tripInfo = {}
            print("------")
            print("s1:",startIndex)
            print("e1:",endIndex)
            print("vs1:", cpyStart)
            print("ve1:", cpyEnd)
            if (cpyStart[startIndex] < cpyEnd[endIndex]):
                print("here1")
                # it is a forward activity
                if startIndex <= len(patients)-1:
                    print("here12")
                    tripInfo = {
                        "origin" : patients[startIndex][2],
                        "destination" : patients[startIndex][3],
                        "arrival" : parseTime(start[startIndex]),
                        "patients" : load.copy()
                    }
                    load.append(startIndex + patientsId)
                else:
                    print("here12")
                    tripInfo = {
                        "origin": patients[startIndex-len(patients)][3],
                        "destination": patients[startIndex-len(patients)][4],
                        "arrival": parseTime(start[startIndex]),
                        "patients": load.copy()
                    }
                    load.append(startIndex + patientsId - len(patients))
                # it is a backward activity
                # ??? the start of the backward is useles??

                print("here13")
                cpyStart[startIndex] = 9999

            # the minimum is on end list
            elif (cpyEnd[endIndex] < cpyStart[startIndex]):
                # it is a forward activity
                print("here2")
                if endIndex <= len(patients)-1:

                    tripInfo = {
                        "origin": patients[endIndex][2],
                        "destination": patients[endIndex][3],
                        "arrival": parseTime(end[endIndex]),
                        "patients": load.copy()
                    }
                    lastTripTime = end[endIndex]
                    lastTripPlace = endIndex
                    secondIndex = 3
                    load.remove(endIndex + patientsId)

                else:
                    tripInfo = {
                        "origin": patients[endIndex-len(patients)][3],
                        "destination": patients[endIndex-len(patients)][4],
                        "arrival": parseTime(end[endIndex]),
                        "patients": load.copy()
                    }

                    lastTripTime = end[endIndex]
                    lastTripPlace = endIndex-len(patients)
                    secondIndex = 4
                    load.remove(endIndex + patientsId - len(patients))
                cpyEnd[endIndex] = 9999


            if tripInfo != {}:
                trips.append(tripInfo)

            startIndex = cpyStart.index(min(cpyStart))
            endIndex = cpyEnd.index(min(cpyEnd))
            print("vs1:", cpyStart)
            print("ve1:", cpyEnd)
            print("vs4:", cpyStart[startIndex])
            print("ve4:", cpyEnd[endIndex])
            print("ve4:", endIndex)

        # add the last trip to the vehicle depot
        print(lastTripPlace)
        print(secondIndex)
        print(vehicleIndex)
        print(patients[lastTripPlace][secondIndex])
        print(vehicles[vehicleIndex][1])

        if vehicles[vehicleIndex][1] != -1:
            tripInfo = {
                "origin": patients[lastTripPlace][secondIndex],
                "destination": vehicles[vehicleIndex][1],
                "arrival": parseTime(lastTripTime+distMatrix[patients[lastTripPlace][secondIndex]][vehicles[vehicleIndex][1]]+patients[lastTripPlace][7]),
                "patients": load.copy()
            }
        print(tripInfo)
        trips.append(tripInfo)
        vehicleInfo = {
            "id" : vehiclesId+vehicleIndex,
            "trips" : trips
        }
        vehiclesOut.append(vehicleInfo)

    output = {
        "requests": len(start) // 2,
        "vehicles": vehiclesOut
    }

    # Serializing json

    #print(outputFile)
    # Writing to sample.json
    with open(outputFile, "w", encoding="utf-8") as outfile:
        json.dump(output, outfile, indent=1)


main()
