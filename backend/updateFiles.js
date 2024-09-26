const fs = require("fs-extra")
const yaml = require("js-yaml")

const contract = process.argv[2]
const newAddress = process.argv[3]

// Update subgraph.yaml
const subgraphYamlFile = "../graph/subgraph.yaml"
const subgraphYaml = yaml.load(fs.readFileSync(subgraphYamlFile, "utf8"))

for (const dataSource of subgraphYaml.dataSources) {
    if (dataSource.name === contract) {
        dataSource.source.address = newAddress
        break
    }
}

fs.writeFileSync(subgraphYamlFile, yaml.dump(subgraphYaml))

// Update networkMapping.json
const networkMappingFile = "../frontend/constants/networkMapping.json"
const networkMappingJson = JSON.parse(
    fs.readFileSync(networkMappingFile, "utf8")
)

networkMappingJson["80001"][contract] = newAddress

fs.writeFileSync(
    networkMappingFile,
    JSON.stringify(networkMappingJson, null, 2)
)
