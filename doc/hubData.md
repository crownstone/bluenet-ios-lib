

# HubData Protocol


| type |  payload | 
| uint8| uint8[] |

## Types

| 0 | setup | setupPayload |


## Payloads

### SetupPayload

| length | hubToken | length | sphereId |
| uint16 | ascii string as uint8[] | length | ascii string as uint8[] |



# HubData Reply

| type | payload |

## Reply Types

| 0 | result | resultPayload |

## Results

| 0 | success
| 1 | success with data | dataLength | data
| 400 | error                  | messageLength | messageAscii


