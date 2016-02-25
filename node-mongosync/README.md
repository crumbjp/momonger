# node-mongosync
Offer the way to replicate from a MongoDB replica-set to another cluster.


## Feature
When using MongoDB, sometime we want a realtime copy cluster.
For example, I want fresh data on the staging environment.

However, MongoDB don't offer the way to do it.

MongoDB replica-set has the OpLog collection for replication for themselves.
`node-mongosync` can read this OpLog and reflect to another cluster.

### Using tailable cursor
OpLog collection is created as a Capped-collection.
Capped-collection is offering the way to read effectively.
`node-mongosync` is using this.

### Bulk operation
`node-mongosync` writes data to destination cluster by using Ordered-bulk-operation.
But command-operation is excepted.
`node-mongosync` executes and waits all Bulk-operation before execute Command-operation.

### Restart
Always logging the reflected OpLog timestamp to destination cluster's collection that specified by config.
`node-mongosync` can continue from certain log at restart.

## MongoDB version
OpLog format might be changed by each MongoDB version.
I don't know the MongoDB's guideline which the OpLog format compatibility is saved or not.
`node-mongosync` guarantee its behavior on MongoDB version by test and human confirmation.

### MongoDB 2.6.X ~ 3.0.X
It's looks like there is the almost perfect compatibility.
I have been run replicate production level TB class cluster from 2.6.X to 3.0.X a year.


## Quick start

#### 1. Download and extract MongoDB
from https://www.mongodb.org/downloads#production

#### 2. Prepare directory
```sh
$ mkdir -p /tmp/mongosync_test
$ cd /tmp/mongosync_test
$ mkdir data1 data2 tmp
```

#### 3. Start source mongod (localhost:27017)
```sh
$ mongod --dbpath ./data1 --logpath ./tmp/1.log --port 27017 --replSet rs --fork
$ mongo <<<"rs.initiate({_id: 'rs', members: [ {_id: 1, host:'localhost:27017'}]})"
```

#### 4. Start destination mongod (localhost:27018)
```sh
$ mongod --dbpath ./data2 --logpath ./tmp/2.log --port 27018 --fork
```

#### 5. Start mongosync
```sh
$ npm install node-mongosync
$ echo "{
  name: 'mongosync_test',
  src: {
    hosts       : ['localhost:27017'],
    replset     : true,
    authdbname  : null,
    user        : null,
    password    : null,
  },
  dst: {
    host        : 'localhost',
    port        : 27018,
    authdbname  : null,
    user        : null,
    password    : null,
    database    : 'test',
    collection  : 'last'
  },
  options: {
    loglv: 'verbose',
    targetDB: {
      'test': 'test2',
      '*': false
    },
    syncIndex: {
      create: true,
      drop: false
    },
    syncCommand: {
      '*': false,
      drop: true,
    },
    dryrun: false,
    bulkIntervalMS: 1000,
    bulkLimit: 5000,
  }
}" > test.conf
$ node ./node_modules/node-mongosync/index.js -c test.conf
```

##### Sync only 'test' database as 'test2' database
```js
targetDB: {
  'test': 'test2',
  '*': false
}
```

##### Sync createIndex but don't sync dropIndex
```js
syncIndex: {
  create: true,
  drop: false
}
```

##### Sync only 'drop' command
```js
syncCommand: {
  '*': false,
  drop: true,
}
```

## Test sync (from another terminal)

#### 1. Basic write operation
```sh
$ mongo localhost:27017/test <<<'
for(i=0;i<10;i++){
 db.tmp.save({a:i})
}
db.tmp.update({a:0}, {$set: {b: 0}})
db.tmp.update({a:{$gt:5}}, {$set: {b: 5}}, {multi: 1})
db.tmp.remove({a:4})
'
WriteResult({ "nInserted" : 1 })
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
WriteResult({ "nMatched" : 20, "nUpserted" : 0, "nModified" : 20 })
WriteResult({ "nRemoved" : 1 })
```

Confirm sync process terminal
```
[verbose]: test2.tmp: i:10, u:21, d:1, U: 0
```

Will sync to destination
```sh
$ mongo localhost:27018/test2 <<<"db.tmp.find()"
{ "_id" : ObjectId("56ce862e9e230530d689b4ed"), "a" : 0, "b" : 0 }
{ "_id" : ObjectId("56ce862e9e230530d689b4ee"), "a" : 1 }
{ "_id" : ObjectId("56ce862e9e230530d689b4ef"), "a" : 2 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f0"), "a" : 3 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f2"), "a" : 5 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f3"), "a" : 6, "b" : 5 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f4"), "a" : 7, "b" : 5 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f5"), "a" : 8, "b" : 5 }
{ "_id" : ObjectId("56ce862e9e230530d689b4f6"), "a" : 9, "b" : 5 }
```

#### 2. createIndex operation
```sh
$ mongo localhost:27017/test <<<'db.tmp.createIndex({a: 1})'
```

Confirm sync process terminal
```
[info]: createIndex test2.tmp { a: 1 } { name: 'a_1' }
```

Will sync to destination
```sh
$ mongo localhost:27018/test2 <<<"db.tmp.stats().indexSizes"
{ "_id_" : 8176, "a_1" : 8176 }
```

#### 3. dropIndex operation
```sh
$ mongo localhost:27017/test <<<'db.tmp.dropIndex("a_1")'
```

Confirm sync process terminal
```
[info]: Skip dropIndex { deleteIndexes: 'tmp', index: 'a_1' }
```

Won't sync to destination
```sh
$ mongo localhost:27018/test2 <<<"db.tmp.stats().indexSizes"
{ "_id_" : 8176, "a_1" : 8176 }
```

#### 4. command operation
```sh
$ mongo localhost:27017/test <<<'
db.tmp.drop()
db.dropDatabase()
'
```

Confirm sync process terminal
```
[info]: command { drop: 'tmp' }
[info]: Skip command {dropDatabase: 1}
```
