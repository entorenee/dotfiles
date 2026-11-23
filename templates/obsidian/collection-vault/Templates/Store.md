---
kind: shop
location:
address:
website:
discogs:
status: open
first_visit:
specialties: []
---

## Notes

## Purchases

```base
filters:
  and:
    - file.inFolder("Releases")
    - file.hasLink(this.file)
views:
  - type: table
    name: Bought here
    order:
      - file.name
      - format
      - condition
      - acquired
    sort:
      - property: acquired
        direction: DESC
```
