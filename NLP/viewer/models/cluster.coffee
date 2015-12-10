'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'
Data = require './data'
Idf = require './idf'

class Cluster extends Base
  initialized: (err, done)->
    @dictionary = new Dictionary @meta.dic
    @idf = new Idf @meta.idf
    @data = new Data @meta.kmeans.data
    async.parallel [
      (done) => @dictionary.init done,
      (done) => @idf.init done,
      (done) => @data.init done,
    ], (err) =>
      done err

  form_cluster: (cluster, n = 4)->
    ls = []
    for id, score of cluster.loc
      ls.push {id, score}
    ls = ls.sort (a, b) -> b.score - a.score
    return {
      _id: cluster._id
      s: cluster.s
      loc: ls[0..n]
    }

  getByLocs: (loc, done)->
    console.log "getByLocs #{loc.length}"
    ids = {}
    for l in loc
      ids[l.id] = 1
    console.log "getByLocs k: #{ids.length}"
    @dictionary.get _.keys(ids), (err, dics)=>
      console.log "getByLocs k: #{ids.length}, r: #{dics.length}"
      dicById = _.indexBy(dics, '_id')
      @idf.get _.keys(ids), (err, idfs)=>
        for idf in idfs
          dicById[idf._id].df = idf.value
          dicById[idf._id].idf = idf.i
        done err, dicById

  getByDocument: (id, done)->
    console.log "getByCluster #{id}"
    @data.get id, (err, document)=>
      cluster_ids = []
      for c in document.cs
        cluster_ids.push c.c
      @getByLocs document.loc, (err, dictionary1)=>
        @clusters cluster_ids, (err, clusters, dictionary2)=>
          dictionary = _.extend dictionary1, dictionary2
          clusterById = _.indexBy(clusters, '_id')
          for c in document.cs
            c.cluster = clusterById[c.c]
          done null, document, dictionary

  getByCluster: (id, done)->
    console.log "getByCluster #{id}"
    @data.getByCluster id, done

  cluster: (id, done)->
    console.log "cluster #{id}"
    @col().findOne
      _id : id
    , (err, cluster) =>
      console.log "cluster found", id
      formed = @form_cluster cluster, 10

      @getByCluster cluster._id, (err, docs) =>
        locs = formed.loc
        for doc in docs
          locs = locs.concat doc.loc

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

    @col().find(query).toArray (err, clusters)=>
      return err if err
      console.log "cluster #{clusters.length}"
      locs = []
      ret = []
      for cluster in clusters
        formed = @form_cluster cluster
        locs = locs.concat formed.loc
        ret.push formed
      ret.sort (a,b)-> b.s - a.s
      @getByLocs locs, (err, dics) =>
        done err, ret, dics

module.exports = Cluster
