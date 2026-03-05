import Foundation

struct AirportSeed {
    let icao: String
    let iata: String
    let name: String
    let country: String
    let lat: Double
    let lon: Double
}

enum AirportsSeedData {

    static let airports: [AirportSeed] = [

        // MOZAMBIQUE
        .init(icao:"FQMA", iata:"MPM", name:"Maputo Intl", country:"MZ", lat:-25.9208, lon:32.5726),
        .init(icao:"FQBR", iata:"BEW", name:"Beira", country:"MZ", lat:-19.7964, lon:34.9076),
        .init(icao:"FQNP", iata:"APL", name:"Nampula", country:"MZ", lat:-15.1056, lon:39.2818),
        .init(icao:"FQVL", iata:"VNX", name:"Vilankulo", country:"MZ", lat:-22.0184, lon:35.3133),
        .init(icao:"FQIN", iata:"INE", name:"Inhambane", country:"MZ", lat:-23.8764, lon:35.4085),

        // SOUTH AFRICA
        .init(icao:"FAOR", iata:"JNB", name:"Johannesburg OR Tambo", country:"ZA", lat:-26.1337, lon:28.2420),
        .init(icao:"FACT", iata:"CPT", name:"Cape Town", country:"ZA", lat:-33.9694, lon:18.5972),
        .init(icao:"FADN", iata:"DUR", name:"King Shaka Intl", country:"ZA", lat:-29.6144, lon:31.1197),
        .init(icao:"FALA", iata:"HLA", name:"Lanseria", country:"ZA", lat:-25.9385, lon:27.9261),
        .init(icao:"FABL", iata:"BFN", name:"Bloemfontein", country:"ZA", lat:-29.0927, lon:26.3024),

        // ZIMBABWE
        .init(icao:"FVHA", iata:"HRE", name:"Harare Intl", country:"ZW", lat:-17.9318, lon:31.0928),
        .init(icao:"FVBU", iata:"BUQ", name:"Bulawayo", country:"ZW", lat:-20.0174, lon:28.6179),
        .init(icao:"FVFA", iata:"VFA", name:"Victoria Falls", country:"ZW", lat:-18.0959, lon:25.8390),

        // KENYA
        .init(icao:"HKJK", iata:"NBO", name:"Jomo Kenyatta Intl", country:"KE", lat:-1.3192, lon:36.9278),
        .init(icao:"HKMO", iata:"MBA", name:"Mombasa Moi Intl", country:"KE", lat:-4.0348, lon:39.5943),
        .init(icao:"HKEL", iata:"EDL", name:"Eldoret Intl", country:"KE", lat:0.4045, lon:35.2389),
        .init(icao:"HKMY", iata:"MYD", name:"Malindi", country:"KE", lat:-3.2293, lon:40.1017)
    ]
}
