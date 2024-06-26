package bootstrap

// HTTPFilterRouter default filter
#HTTPFilterRouter: #HTTPFilter & {
    name: "envoy.filters.http.router"
	typed_config: "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
}

#AdminServer: {
	access_log_path: string | *"/dev/null"
	address: #Address & { socket_address: {
        address: "127.0.0.1"
        port_value: 19000
        }
    }
}

#ReadyServer: {
    Address: string | *"0.0.0.0"
    Port:    int | *19001
    ReadinessPath: string | *"/ready"
}

#AccessLog: [{
    name: "envoy.access_loggers.stdout"
    typed_config: "@type": "type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog"
}]

// #ExtAuthzOPAServiceFilter: #HTTPFilter & {
//     name: "envoy.filters.http.ext_authz"
//     typed_config: {
//         "@type": "type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz"
//         with_request_body: {
//             max_request_bytes:     8192
//             allow_partial_message: true
//         }
//         failure_mode_allow: false
//         grpc_service: {
//             envoy_grpc: cluster_name: #ExtAuthzOPAService.load_assignment.cluster_name
//             timeout: "0.250s"
//         }
//         transport_api_version: "V3"
//     }
// }

// #ExtAuthzOPAService: #Cluster & {
//     name:      "ext_authz-opa-service"
//     load_assignment: {
//         cluster_name: "ext_authz-opa-service"
//         endpoints: [{
//             lb_endpoints: [{endpoint: {
//                 address: { socket_address: {
//                     address: "ext_authz-http-service"
//                     port_value: 8181
//                 }}}
//             }]
//         }]
//     }
// }

#LocalServiceCluster: #Cluster & {
    name:      "local_service_cluster"
    load_assignment: {
        cluster_name: "local_service_cluster"
        endpoints: [{
            lb_endpoints: [{endpoint: {
                address: { socket_address: {
                    address: "local_service"
                    port_value: #GoLocalServicePort
                }}}
            }]
        }]
    }
}

#Listener0: #Listener & {
    name: "listener_0"
    address: #Address & { socket_address: {
        address: "0.0.0.0"
        port_value: 8000
        }
    }
    filter_chains: [{
        filters: [{
            name: "envoy.filters.network.http_connection_manager.https"
            typed_config: {
                "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager"
				stat_prefix: "ingress_https"
                access_log: #AccessLog
                upgrade_configs: [{
                    upgrade_type: "websocket"
                }]
                http_filters: #GoHttpFilters
                route_config: {
                    name: "local_route"
                    virtual_hosts: [{
                        name: "local_service"
                        domains: ["*"]
                        routes: [{
                            match: {prefix: "/"}
                            route: {cluster: #LocalServiceCluster.load_assignment.cluster_name}
                        }]
                    }]
                }
            }
        }]
    }]
}

// Define go types
#GoLocalServicePort: #Port | *3000
#GoHttpFilters: [...#HTTPFilter]
#GoClusters: [...#Cluster]

#BootstrapConfig: {
    listeners: #Listeners & [#Listener0]
    clusters: [#LocalServiceCluster] + #GoClusters
}

admin: #AdminServer
static_resources: #BootstrapConfig
