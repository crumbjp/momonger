'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'
Data = require './data'
Idf = require './idf'

class Cluster extends Base
  initialized: (done)->
    @getmeta (err, @meta)=>
      @dictionary ||= new Dictionary @meta.dictionary
      @idf = new Idf @meta.idf
      @data = new Data @meta.kmeans.data
      done err

  form_cluster: (cluster, head = 4)->
    ls = []
    for id, score of cluster.v
      ls.push {id, score}
    ls = ls.sort (a, b) -> b.score - a.score
    return {
      _id: cluster._id
      name: cluster.name
      n: cluster.n
      loc: ls[0..head]
    }

  getByLocs: (loc, done)->
    console.log "getByLocs #{loc.length}"
    ids = {}
    idsLen = 0
    for l in loc
      idsLen++
      ids[l.id] = 1
    @dictionary.get _.keys(ids), (err, dics)=>
      console.log "getByLocs k: #{idsLen}, d: #{dics.length}"
      dicById = _.indexBy(dics, '_id')
      @idf.get _.keys(ids), (err, idfs)=>
        console.log "getByLocs k: #{idsLen}, i: #{dics.length}"
        for idf in idfs
          dicById[idf._id].idf = idf.value if dicById[idf._id]
        done err, dicById

  getByDocument: (id, done)->
    console.log "getByDocument #{id}"
    @data.get id, (err, document)=>
      cluster_ids = []
      for c in document.cs
        cluster_ids.push c._id
      @getByLocs document.loc, (err, dictionary1)=>
        @clusters cluster_ids, (err, clusters, dictionary2)=>
          dictionary = _.extend dictionary1, dictionary2
          clusterById = _.indexBy(clusters, '_id')
          for c in document.cs
            c.n = clusterById[c._id].n
            c.loc = clusterById[c._id].loc
            c.name = clusterById[c._id].name

          done null, document, dictionary

  getByCluster: (id, done)->
    console.log "getByCluster #{id}"
    @data.getByCluster id, done

  cluster: (id, done)->
    console.log "cluster #{id}"
    @findOne
      _id : mongodb.ObjectId(id)
    , (err, cluster) =>
      console.log "cluster found", cluster._id
      formed = @form_cluster cluster, 50

      @getByCluster cluster._id, (err, docs) =>
        cluster_ids = []
        locs = formed.loc
        for doc in docs
          locs = locs.concat doc.loc
          for c in doc.cs
            cluster_ids.push c._id
        cluster_ids =_.uniq cluster_ids
        @clusters cluster_ids, (err, clusters, dictionary)=>
          clusterById = _.indexBy(clusters, '_id')
          for doc in docs
            for c in doc.cs
              c.n = clusterById[c._id].n
              c.loc = clusterById[c._id].loc
              c.name = clusterById[c._id].name

          @getByLocs locs, (err, dics) =>
            done err, formed, docs, dics

  clusters: (ids, done)->
    console.log "clusters"
    query =
      _id :
        $ne: '.meta'
    if ids
      query =
        _id :
          $in: ids

    @findAsArray query, (err, clusters)=>
      return err if err
      console.log "cluster #{clusters.length}"
      locs = []
      ret = []
      for cluster in clusters
        formed = @form_cluster cluster
        locs = locs.concat formed.loc
        ret.push formed
      ret.sort (a,b)-> b.n - a.n
      @getByLocs locs, (err, dics) =>
        done err, ret, dics

  updateById: (id, update, done)->
    @update {_id: mongodb.ObjectId(id)}, update, done

module.exports = Cluster
