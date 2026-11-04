import json

def parse(s):
    return json.loads(s)

def main():
    parse("{bad")

main()
