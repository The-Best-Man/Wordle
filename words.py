
output = open("words.txt", "w")

with open("english.txt", "r") as file:
    for line in file:
        string = line.strip()
        if (len(string) == 5):
            output.write(string + "\n")

output.close()

