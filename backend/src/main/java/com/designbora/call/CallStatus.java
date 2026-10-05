package com.designbora.call;

public enum CallStatus {
    RINGING,   // inaita
    ACCEPTED,  // imepokelewa, mazungumzo yanaendelea
    REJECTED,  // imekataliwa na anayepigiwa
    MISSED,    // haikupokelewa (muda umeisha au mpigaji amekata kabla)
    ENDED      // imekamilika baada ya mazungumzo
}
